package com.browser.crockbrowser.browser;

import android.net.Uri;
import android.os.SystemClock;
import android.webkit.WebView;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import com.browser.crockbrowser.core.HostChannel;
import com.browser.crockbrowser.core.JsonCodec;
import com.browser.crockbrowser.downloads.YouTubeExtractor;
import java.util.Set;
import java.util.function.BooleanSupplier;
import org.json.JSONObject;

/** Origin-restricted bridge: webpage messages can request a picker, never start a transfer. */
final class YouTubePageBridge {
  private static final Set<String> ORIGINS =
      Set.of(
          "https://www.youtube.com",
          "https://m.youtube.com",
          "https://youtube.com",
          "https://music.youtube.com");
  private final WebView view;
  private final HostChannel host;
  private final BooleanSupplier active;
  private String preparedUrl = "";
  private long lastRequest;
  private boolean disposed;

  YouTubePageBridge(HostChannel host, WebView view, int id, BooleanSupplier active) {
    this.view = view;
    this.host = host;
    this.active = active;
    if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))
      WebViewCompat.addWebMessageListener(
          view,
          "crockVideoDownload",
          ORIGINS,
          (webView, message, origin, mainFrame, reply) -> {
            if (disposed
                || !mainFrame
                || !active.getAsBoolean()
                || !"https".equals(origin.getScheme())
                || !Set.of("youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com")
                    .contains(origin.getHost())
                || (origin.getPort() != -1 && origin.getPort() != 443)
                || SystemClock.elapsedRealtime() - lastRequest < 1200) return;
            try {
              String data = message.getData();
              if (data == null || data.length() > 2048) return;
              JSONObject request = new JSONObject(data);
              String url = YouTubeExtractor.canonicalUrl(request.getString("url"));
              if (!url.equals(YouTubeExtractor.canonicalUrl(view.getUrl()))) return;
              if (!origin.getHost().equals(Uri.parse(view.getUrl()).getHost())) return;
              if ("prepare".equals(request.optString("action"))) {
                prepare(url);
                return;
              }
              JSONObject rect = request.optJSONObject("anchor");
              lastRequest = SystemClock.elapsedRealtime();
              host.emit(
                  JsonCodec.map(
                      "type",
                      "youtubeDownload",
                      "view",
                      id,
                      "url",
                      url,
                      "anchor",
                      rect == null ? null : JsonCodec.unwrap(rect)));
            } catch (Exception ignored) {
              /* Ignore malformed or unrelated page messages. */
            }
          });
  }

  void finished() {
    if (disposed || !WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) return;
    try {
      Uri uri = Uri.parse(view.getUrl());
      String origin = uri.getScheme() + "://" + uri.getAuthority();
      if (ORIGINS.contains(origin)) view.evaluateJavascript(SCRIPT, null);
    } catch (Exception ignored) {
      /* Non-web and loading pages do not have controls. */
    }
  }

  void prepare(String url) {
    if (disposed || !active.getAsBoolean()) return;
    try {
      String canonical = YouTubeExtractor.canonicalUrl(url);
      if (!canonical.equals(preparedUrl)) {
        preparedUrl = canonical;
        host.prepareYouTube(canonical);
      }
    } catch (IllegalArgumentException ignored) {
      // Home/search/non-video pages have no qualities to prepare.
    }
  }

  void dispose() {
    disposed = true;
    if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))
      WebViewCompat.removeWebMessageListener(view, "crockVideoDownload");
  }

  static final String SCRIPT =
      """
      (() => {
        if (!window.crockVideoDownload) return false;
        if (window.__crockVideoControl) { window.__crockVideoControl.refresh(); return true; }
        let button, scheduled = false, preparedId = '';
        const videoId = () => {
          const url = new URL(location.href);
          const id = url.pathname === '/watch' ? url.searchParams.get('v') : url.pathname.match(/^\\/(shorts|embed)\\/([^/]+)/)?.[2];
          return id && /^[A-Za-z0-9_-]{11}$/.test(id) ? id : null;
        };
        const findLike = () => {
          const area = document.querySelector('ytd-watch-metadata,ytm-watch,ytm-watch-flexy,ytd-watch-flexy') || document;
          return area.querySelector('segmented-like-dislike-button-view-model,ytm-segmented-like-dislike-button-renderer,ytd-segmented-like-dislike-button-renderer,ytm-like-button-renderer,like-button-view-model') ||
            Array.from(area.querySelectorAll('ytm-slim-video-action-bar-renderer button,#top-level-buttons-computed button'))
              .find(node => /\\blike\\b/i.test(node.getAttribute('aria-label') || '') && !/dislike/i.test(node.getAttribute('aria-label') || ''));
        };
        const refresh = () => {
          scheduled = false;
          const id = videoId();
          if (id && id !== preparedId) {
            preparedId = id;
            window.crockVideoDownload.postMessage(JSON.stringify({action:'prepare',url:location.href}));
          }
          const anchor = videoId() && findLike();
          if (!anchor || !anchor.parentElement) { button?.remove(); return; }
          if (!button) {
            button = document.createElement('button');
            button.id = '__crock_youtube_download';
            button.type = 'button';
            button.title = 'Download video';
            button.setAttribute('aria-label', 'Download video');
            button.style.cssText = 'display:inline-flex;align-items:center;justify-content:center;flex-shrink:0;width:36px;height:36px;padding:0;margin-inline-end:8px;border:0;border-radius:18px;background:rgba(128,128,128,.16);color:inherit;cursor:pointer;vertical-align:middle';
            // YouTube requires TrustedHTML: construct the icon without an HTML sink.
            const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            for (const [name, value] of Object.entries({
              'aria-hidden':'true',viewBox:'0 0 24 24',width:'20',height:'20',
              fill:'none',stroke:'currentColor','stroke-width':'1.8',
              'stroke-linecap':'round','stroke-linejoin':'round'
            })) svg.setAttribute(name, value);
            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            path.setAttribute('d', 'M12 3v12m-4-4 4 4 4-4M5 16v4h14v-4');
            svg.appendChild(path);
            button.appendChild(svg);
            button.addEventListener('click', event => {
              event.preventDefault(); event.stopImmediatePropagation();
              if (!event.isTrusted || !videoId()) return;
              const rect = button.getBoundingClientRect();
              window.crockVideoDownload.postMessage(JSON.stringify({url:location.href,anchor:{
                left:rect.left/innerWidth,top:rect.top/innerHeight,width:rect.width/innerWidth,height:rect.height/innerHeight
              }}));
            });
          }
          if (anchor.previousElementSibling !== button) anchor.parentElement.insertBefore(button, anchor);
        };
        const schedule = () => { if (!scheduled) { scheduled = true; requestAnimationFrame(refresh); } };
        const observer = new MutationObserver(schedule);
        observer.observe(document, {childList:true,subtree:true});
        addEventListener('yt-navigate-finish', schedule);
        addEventListener('yt-page-data-updated', schedule);
        addEventListener('popstate', schedule);
        window.__crockVideoControl = {refresh:schedule};
        schedule();
        return true;
      })()
      """;
}
