package com.example.crocbrowser.browser;

import android.annotation.SuppressLint;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Message;
import android.view.View;
import android.webkit.*;
import com.example.crocbrowser.core.HostChannel;
import com.example.crocbrowser.core.JsonCodec;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.util.*;

public final class BrowserView implements PlatformView {
  private final HostChannel host;
  private final int id;
  private final WebView view;
  private final MethodChannel channel;
  private final Set<String> media = java.util.concurrent.ConcurrentHashMap.newKeySet();
  private boolean failed = false, blockAds = false, disposed = false;
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
    view = new WebView(host.activity);
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
            failed = false;
            media.clear();
            state(0);
          }

          @Override
          public void onPageFinished(WebView v, String url) {
            state(100);
            host.applyHiddenElements(view);
          }

          @Override
          public void onReceivedError(WebView v, WebResourceRequest r, WebResourceError error) {
            if (r.isForMainFrame()) {
              failed = true;
              state(100);
            }
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
                && path.toLowerCase(Locale.ROOT).matches(".*\\.(mp4|webm|mp3|m4a|ogg|m3u8)(/.*)?$")
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
    channel = new MethodChannel(host.messenger, "croc/webview/" + id);
    channel.setMethodCallHandler(
        (call, result) -> {
          try {
            Map<String, Object> data =
                call.arguments instanceof Map
                    ? (Map<String, Object>) call.arguments
                    : new HashMap<>();
            switch (call.method) {
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
              case "settings":
                configure(data);
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
                evaluate(BrowserScripts.MEDIA, result);
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

  private void configure(Map<String, Object> args) {
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
    return view;
  }

  @Override
  public void dispose() {
    disposed = true;
    channel.setMethodCallHandler(null);
    view.stopLoading();
    view.destroy();
  }
}
