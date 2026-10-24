package com.example.crocbrowser.browser;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Rect;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.view.ContextThemeWrapper;
import android.view.MotionEvent;
import android.view.PixelCopy;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.webkit.*;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import androidx.webkit.WebSettingsCompat;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import com.example.crocbrowser.browser.credentials.LoginCapture;
import com.example.crocbrowser.core.HostChannel;
import com.example.crocbrowser.core.JsonCodec;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.util.*;

public final class BrowserView implements PlatformView {
  private final HostChannel host;
  private final int id;
  private final ContextThemeWrapper webContext;
  private final WebView view;
  private final SwipeRefreshLayout refreshLayout;
  private final LoginCapture loginCapture;
  private final MethodChannel channel;
  private final Set<String> media = java.util.concurrent.ConcurrentHashMap.newKeySet();
  private boolean failed = false, blockAds = false, disposed = false, darkTheme = false;
  private boolean active = true;
  private boolean touching = false, draggingPage = false;
  private float touchX, touchY;
  private String normalAgent, lastTitle = "";
  private static final String[] AD_HOSTS = {
    "doubleclick.net",
    "googlesyndication.com",
    "googleadservices.com",
    "adsystem.com",
    "adnxs.com",
    "adsrvr.org",
    "taboola.com",
    "outbrain.com",
    "scorecardresearch.com",
    "criteo.com",
    "pubmatic.com",
    "openx.net",
    "rubiconproject.com"
  };

  @SuppressLint("SetJavaScriptEnabled")
  public BrowserView(HostChannel host, int id, Map<String, Object> args) {
    this.host = host;
    this.id = id;
    webContext =
        new ContextThemeWrapper(
            host.activity,
            Boolean.TRUE.equals(args.get("darkTheme"))
                ? com.example.crocbrowser.R.style.BrowserWebViewDarkTheme
                : com.example.crocbrowser.R.style.BrowserWebViewLightTheme);
    view = new WebView(webContext);
    active = Boolean.TRUE.equals(args.get("active"));
    if (WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO))
      WebViewCompat.setAudioMuted(view, !active);
    refreshLayout = new SwipeRefreshLayout(host.activity);
    refreshLayout.setColorSchemeResources(android.R.color.holo_blue_dark);
    refreshLayout.addView(
        view,
        new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    refreshLayout.setOnRefreshListener(view::reload);
    loginCapture = new LoginCapture(host, view, id);
    WebSettings s = view.getSettings();
    normalAgent = s.getUserAgentString();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setBuiltInZoomControls(true);
    s.setDisplayZoomControls(false);
    s.setUseWideViewPort(true);
    s.setLoadWithOverviewMode(true);
    s.setAllowFileAccess(false);
    s.setAllowContentAccess(false);
    s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
    s.setSupportMultipleWindows(true);
    s.setSafeBrowsingEnabled(true);
    CookieManager.getInstance().setAcceptThirdPartyCookies(view, false);
    configure(args);
    view.setDownloadListener(
        (url, agent, disposition, mime, length) -> {
          String cookie = CookieManager.getInstance().getCookie(url);
          host.emit(
              JsonCodec.map(
                  "type",
                  "download",
                  "view",
                  id,
                  "url",
                  url,
                  "name",
                  URLUtil.guessFileName(url, disposition, mime),
                  "mime",
                  mime == null ? "application/octet-stream" : mime,
                  "total",
                  length,
                  "headers",
                  JsonCodec.map(
                      "User-Agent",
                      agent,
                      "Referer",
                      view.getUrl() == null ? "" : view.getUrl(),
                      "Cookie",
                      cookie == null ? "" : cookie)));
        });
    view.setWebViewClient(
        new WebViewClient() {
          @Override
          public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest request) {
            String scheme = request.getUrl().getScheme();
            if ("http".equals(scheme) || "https".equals(scheme)) return false;
            if ("file".equals(scheme) && host.isOfflinePath(request.getUrl().getPath()))
              return false;
            host.emit(
                JsonCodec.map(
                    "type", "externalLink", "view", id, "url", request.getUrl().toString()));
            return true;
          }

          @Override
          public void onPageStarted(WebView v, String url, Bitmap icon) {
            draggingPage = false;
            loginCapture.started(url);
            failed = false;
            media.clear();
            state(0);
          }

          @Override
          public void onPageFinished(WebView v, String url) {
            refreshLayout.setRefreshing(false);
            state(100);
            host.applyHiddenElements(view);
            loginCapture.finished();
            applyMediaActivity();
            emitScroll(0, "page");
          }

          @Override
          public void onReceivedError(WebView v, WebResourceRequest r, WebResourceError error) {
            if (r.isForMainFrame()) {
              refreshLayout.setRefreshing(false);
              loginCapture.clear();
              failed = true;
              state(100);
            }
          }

          @Override
          public void onReceivedHttpError(
              WebView v, WebResourceRequest request, WebResourceResponse response) {
            if (request.isForMainFrame() && response.getStatusCode() >= 400) loginCapture.clear();
          }

          @Override
          public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest request) {
            String domain = request.getUrl().getHost();
            if (blockAds && domain != null)
              for (String suffix : AD_HOSTS)
                if (domain.equals(suffix) || domain.endsWith("." + suffix))
                  return new WebResourceResponse(
                      "text/plain", "UTF-8", new ByteArrayInputStream(new byte[0]));
            String url = request.getUrl().toString();
            String path = request.getUrl().getPath();
            if (path != null
                && path.toLowerCase(Locale.ROOT)
                    .matches(".*\\.(mp4|webm|mp3|m4a|aac|ogg|wav|m3u8|mpd)(/.*)?$")
                && media.add(url))
              host.emit(
                  JsonCodec.map(
                      "type",
                      "media",
                      "view",
                      id,
                      "url",
                      url,
                      "title",
                      URLUtil.guessFileName(url, null, null)));
            return null;
          }
        });
    view.setWebChromeClient(
        new WebChromeClient() {
          @Override
          public void onReceivedIcon(WebView v, Bitmap icon) {
            if (icon == null
                || v.getUrl() == null
                || host.activity instanceof com.example.crocbrowser.PrivateBrowserActivity) return;
            java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
            int largest = Math.max(icon.getWidth(), icon.getHeight());
            Bitmap small =
                largest > 128
                    ? Bitmap.createScaledBitmap(
                        icon,
                        Math.max(1, icon.getWidth() * 128 / largest),
                        Math.max(1, icon.getHeight() * 128 / largest),
                        true)
                    : icon;
            small.compress(Bitmap.CompressFormat.PNG, 100, bytes);
            if (bytes.size() <= 512 * 1024)
              host.emit(
                  JsonCodec.map(
                      "type",
                      "favicon",
                      "view",
                      id,
                      "url",
                      v.getUrl(),
                      "bytes",
                      bytes.toByteArray()));
          }

          @Override
          public void onProgressChanged(WebView v, int progress) {
            state(progress);
          }

          @Override
          public void onReceivedTitle(WebView v, String title) {
            if (title != null && title.startsWith("CROC_HIDE:")) {
              host.saveHiddenElement(v, title.substring(10));
              v.evaluateJavascript("document.title=" + org.json.JSONObject.quote(lastTitle), null);
            } else {
              lastTitle = title == null ? "" : title;
              state(v.getProgress());
            }
          }

          @Override
          public boolean onCreateWindow(
              WebView v, boolean dialog, boolean gesture, Message message) {
            if (!gesture) return false;
            WebView popup = new WebView(host.activity);
            popup.setWebViewClient(
                new WebViewClient() {
                  @Override
                  public boolean shouldOverrideUrlLoading(WebView p, WebResourceRequest r) {
                    host.emit(
                        JsonCodec.map("type", "newTab", "view", id, "url", r.getUrl().toString()));
                    p.destroy();
                    return true;
                  }
                });
            ((WebView.WebViewTransport) message.obj).setWebView(popup);
            message.sendToTarget();
            return true;
          }

          @Override
          public boolean onShowFileChooser(
              WebView v, ValueCallback<Uri[]> callback, FileChooserParams params) {
            host.chooseWebFiles(callback, params);
            return true;
          }

          @Override
          public void onPermissionRequest(PermissionRequest request) {
            host.askWebsitePermission(request);
          }

          @Override
          public void onShowCustomView(View custom, CustomViewCallback callback) {
            host.showFullscreen(custom, callback);
          }

          @Override
          public void onHideCustomView() {
            host.hideFullscreen();
          }
        });
    view.setOnLongClickListener(
        v -> {
          WebView.HitTestResult hit = view.getHitTestResult();
          if (hit.getExtra() == null) return false;
          host.emit(
              JsonCodec.map(
                  "type", "context", "view", id, "url", hit.getExtra(), "kind", hit.getType()));
          return true;
        });
    // Flutter observes drag distance in stable screen coordinates. Native scroll
    // events supply viewport metadata and inertia after the finger is released.
    view.setOnTouchListener(
        (v, event) -> {
          float y = event.getRawY();
          switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
              touching = true;
              draggingPage = false;
              touchX = event.getRawX();
              touchY = y;
              break;
            case MotionEvent.ACTION_MOVE:
              float distance = touchY - y;
              if (!draggingPage
                  && Math.abs(distance) > ViewConfiguration.get(v.getContext()).getScaledTouchSlop()
                  && Math.abs(distance) > Math.abs(event.getRawX() - touchX)) draggingPage = true;
              break;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL:
              touching = false;
              break;
            default:
              break;
          }
          return false;
        });
    view.setOnScrollChangeListener(
        (v, scrollX, scrollY, oldScrollX, oldScrollY) -> {
          int delta = scrollY - oldScrollY;
          emitScroll(delta, !touching && draggingPage ? "fling" : "page");
        });
    channel = new MethodChannel(host.messenger, "croc/webview/" + id);
    channel.setMethodCallHandler(
        (call, result) -> {
          try {
            Map<String, Object> data =
                call.arguments instanceof Map
                    ? (Map<String, Object>) call.arguments
                    : new HashMap<>();
            switch (call.method) {
              case "setActive":
                setActive(Boolean.TRUE.equals(data.get("active")));
                result.success(null);
                break;
              case "load":
                load(JsonCodec.string(data, "url", ""));
                result.success(null);
                break;
              case "back":
                view.goBack();
                result.success(null);
                break;
              case "forward":
                view.goForward();
                result.success(null);
                break;
              case "reload":
                view.reload();
                result.success(null);
                break;
              case "captureThumbnail":
                captureThumbnail(result);
                break;
              case "settings":
                boolean previousDarkTheme = darkTheme;
                configure(data);
                if (previousDarkTheme != darkTheme && view.getUrl() != null) view.reload();
                result.success(null);
                break;
              case "find":
                view.findAllAsync(JsonCodec.string(data, "text", ""));
                result.success(null);
                break;
              case "findNext":
                view.findNext(!Boolean.FALSE.equals(data.get("forward")));
                result.success(null);
                break;
              case "reader":
                evaluate(BrowserScripts.READER, result);
                break;
              case "media":
                evaluate(PageMediaExtractor.SCRIPT, result);
                break;
              case "requestContext":
                String target = JsonCodec.string(data, "url", "");
                String cookies = CookieManager.getInstance().getCookie(target);
                result.success(
                    JsonCodec.map(
                        "User-Agent",
                        view.getSettings().getUserAgentString(),
                        "Referer",
                        view.getUrl() == null ? "" : view.getUrl(),
                        "Cookie",
                        cookies == null ? "" : cookies));
                break;
              case "form":
                evaluate(BrowserScripts.FORM, result);
                break;
              case "fill":
                String origin =
                    Uri.parse(view.getUrl()).getScheme()
                        + "://"
                        + Uri.parse(view.getUrl()).getAuthority();
                if (!origin.equals(data.get("origin")))
                  throw new SecurityException("Saved login does not match this website");
                evaluate(
                    BrowserScripts.fill(
                        JsonCodec.string(data, "username", ""),
                        JsonCodec.string(data, "password", "")),
                    result);
                break;
              case "fillProfile":
                String currentOrigin =
                    Uri.parse(view.getUrl()).getScheme()
                        + "://"
                        + Uri.parse(view.getUrl()).getAuthority();
                if (!currentOrigin.equals(data.get("origin")))
                  throw new SecurityException("The website changed before autofill");
                String profile = new org.json.JSONObject(data).toString();
                evaluate(
                    "(()=>{const profile="
                        + profile
                        + ";let count=0;for(const el of"
                        + " document.querySelectorAll('input,textarea')){if(el.disabled||el.readOnly||['password','hidden','submit','button','checkbox','radio'].includes(el.type)||!el.getClientRects().length)continue;let"
                        + " key=(el.autocomplete||'').split(' ').pop();if(!profile[key]){const"
                        + " hint=((el.name||'')+'"
                        + " '+(el.id||'')).toLowerCase();key=el.type==='email'||hint.includes('email')?'email':el.type==='tel'||hint.includes('phone')?'tel':hint.includes('fullname')||hint.includes('full_name')?'name':hint.includes('postcode')||hint.includes('zip')?'postal-code':hint.includes('city')?'address-level2':hint.includes('street')?'street-address':'';}if(profile[key]){const"
                        + " proto=el.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;Object.getOwnPropertyDescriptor(proto,'value').set.call(el,profile[key]);el.dispatchEvent(new"
                        + " Event('input',{bubbles:true}));el.dispatchEvent(new"
                        + " Event('change',{bubbles:true}));count++;}}return count;})()",
                    result);
                break;
              case "pickElement":
                view.evaluateJavascript(BrowserScripts.PICK_ELEMENT, null);
                result.success(null);
                break;
              case "offline":
                host.saveOffline(view, result);
                break;
              case "openOffline":
                String path = JsonCodec.string(data, "path", "");
                if (!host.isOfflinePath(path)) throw new SecurityException("Invalid offline page");
                view.getSettings().setAllowFileAccess(true);
                view.loadUrl(Uri.fromFile(new File(path)).toString());
                result.success(null);
                break;
              default:
                result.notImplemented();
            }
          } catch (Exception error) {
            result.error("BROWSER", error.getMessage(), null);
          }
        });
    String url = JsonCodec.string(args, "url", "");
    if (!url.isEmpty()) load(url);
  }

  private void emitScroll(float delta, String source) {
    float density = view.getResources().getDisplayMetrics().density;
    host.emit(
        JsonCodec.map(
            "type",
            "scroll",
            "view",
            id,
            "y",
            view.getScrollY() / density,
            "deltaY",
            delta / density,
            "source",
            source,
            "canScroll",
            view.canScrollVertically(1) || view.canScrollVertically(-1)));
  }

  private void setActive(boolean next) {
    if (disposed) return;
    active = next;
    // Muting also covers cross-origin players and WebAudio that DOM queries cannot reach.
    if (WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO))
      WebViewCompat.setAudioMuted(view, !active);
    if (active) view.onResume();
    applyMediaActivity();
    if (!active) view.onPause();
  }

  private void applyMediaActivity() {
    if (disposed) return;
    view.evaluateJavascript(
        "(()=>{const update=w=>{try{w.__crockMediaActive="
            + active
            + ";"
            + "if(!w.__crockMediaGuard){w.__crockMediaGuard=true;"
            + "w.document.addEventListener('play',e=>{if(w.__crockMediaActive===false"
            + "&&e.target.pause)e.target.pause();},true);}"
            + "if(!w.__crockMediaActive)w.document.querySelectorAll('video,audio')"
            + ".forEach(m=>m.pause());"
            + "for(let i=0;i<w.frames.length;i++)update(w.frames[i]);}catch(_){}};"
            + "update(window);})()",
        null);
  }

  private void configure(Map<String, Object> args) {
    loginCapture.configure(args);
    if (args.containsKey("darkTheme")) {
      darkTheme = Boolean.TRUE.equals(args.get("darkTheme"));
      webContext.setTheme(
          darkTheme
              ? com.example.crocbrowser.R.style.BrowserWebViewDarkTheme
              : com.example.crocbrowser.R.style.BrowserWebViewLightTheme);
      if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING))
        WebSettingsCompat.setAlgorithmicDarkeningAllowed(view.getSettings(), darkTheme);
    }
    if (args.containsKey("desktop"))
      view.getSettings()
          .setUserAgentString(
              Boolean.TRUE.equals(args.get("desktop"))
                  ? normalAgent.replace("Android", "X11; Linux x86_64").replace("Mobile", "")
                  : normalAgent);
    if (args.containsKey("font"))
      view.getSettings().setTextZoom(JsonCodec.integer(args, "font", 100));
    if (args.containsKey("adBlock")) blockAds = Boolean.TRUE.equals(args.get("adBlock"));
  }

  private void captureThumbnail(MethodChannel.Result result) {
    if (disposed || view.getWidth() <= 0 || view.getHeight() <= 0) {
      result.success(null);
      return;
    }

    // Copy the actual composed WebView pixels from the window. WebView.draw()
    // uses a software canvas and can miss Chromium's GPU-rendered layers,
    // leaving only fragments of pages such as YouTube in the tab preview.
    int[] location = new int[2];
    view.getLocationInWindow(location);
    Rect source =
        new Rect(
            location[0],
            location[1],
            location[0] + view.getWidth(),
            location[1] + view.getHeight());
    Bitmap bitmap = Bitmap.createBitmap(360, 400, Bitmap.Config.ARGB_8888);
    try {
      PixelCopy.request(
          host.activity.getWindow(),
          source,
          bitmap,
          copyResult -> {
            try {
              if (disposed) {
                result.success(null);
                return;
              }
              if (copyResult != PixelCopy.SUCCESS || isBlack(bitmap)) {
                Bitmap fallback = captureWebViewFrame();
                if (fallback == null) {
                  result.success(null);
                  return;
                }
                try {
                  result.success(encodeThumbnail(fallback));
                } finally {
                  fallback.recycle();
                }
                return;
              }
              result.success(encodeThumbnail(bitmap));
            } catch (RuntimeException error) {
              result.error("BROWSER", "Could not capture this page preview", null);
            } finally {
              bitmap.recycle();
            }
          },
          new Handler(Looper.getMainLooper()));
    } catch (RuntimeException error) {
      bitmap.recycle();
      Bitmap fallback = captureWebViewFrame();
      if (fallback == null) {
        result.error("BROWSER", "Could not capture this page preview", null);
        return;
      }
      try {
        result.success(encodeThumbnail(fallback));
      } finally {
        fallback.recycle();
      }
    }
  }

  private static byte[] encodeThumbnail(Bitmap bitmap) {
    ByteArrayOutputStream output = new ByteArrayOutputStream();
    bitmap.compress(Bitmap.CompressFormat.JPEG, 76, output);
    return output.toByteArray();
  }

  private static boolean isBlack(Bitmap bitmap) {
    int black = 0;
    int sampled = 0;
    for (int y = 4; y < bitmap.getHeight(); y += 12) {
      for (int x = 4; x < bitmap.getWidth(); x += 12) {
        int pixel = bitmap.getPixel(x, y);
        if (Color.red(pixel) < 6 && Color.green(pixel) < 6 && Color.blue(pixel) < 6) black++;
        sampled++;
      }
    }
    return sampled > 0 && black >= sampled * 0.98;
  }

  private Bitmap captureWebViewFrame() {
    if (disposed || view.getWidth() <= 0 || view.getHeight() <= 0) return null;
    Bitmap bitmap = Bitmap.createBitmap(360, 400, Bitmap.Config.ARGB_8888);
    try {
      Canvas canvas = new Canvas(bitmap);
      canvas.drawColor(Color.WHITE);
      float scale = 360f / view.getWidth();
      // WebView.draw() already accounts for its current scroll offset. Drawing
      // a whole-document Picture and translating it here can move the viewport
      // past its content after a longer scroll, leaving a mostly blank preview.
      canvas.scale(scale, scale);
      view.draw(canvas);
      return bitmap;
    } catch (RuntimeException error) {
      bitmap.recycle();
      return null;
    }
  }

  private void load(String url) {
    Uri uri = Uri.parse(url);
    if (!"https".equalsIgnoreCase(uri.getScheme()) && !"http".equalsIgnoreCase(uri.getScheme()))
      throw new IllegalArgumentException("Enter a web address");
    view.getSettings().setAllowFileAccess(false);
    view.loadUrl(url);
  }

  private void evaluate(String script, MethodChannel.Result result) {
    view.evaluateJavascript(
        script,
        json -> {
          try {
            Object value = new org.json.JSONTokener(json).nextValue();
            if (value instanceof String)
              value = new org.json.JSONTokener((String) value).nextValue();
            result.success(JsonCodec.unwrap(value));
          } catch (Exception e) {
            result.error("PAGE_DATA", "Cannot read this page", null);
          }
        });
  }

  private void state(int progress) {
    if (disposed) return;
    host.emit(
        JsonCodec.map(
            "type",
            "browser",
            "view",
            id,
            "url",
            view.getUrl() == null ? "" : view.getUrl(),
            "title",
            view.getTitle() == null ? "" : view.getTitle(),
            "progress",
            progress,
            "failed",
            failed,
            "back",
            view.canGoBack(),
            "forward",
            view.canGoForward()));
  }

  @Override
  public View getView() {
    return refreshLayout;
  }

  @Override
  public void dispose() {
    disposed = true;
    loginCapture.dispose();
    channel.setMethodCallHandler(null);
    view.stopLoading();
    view.destroy();
  }
}
