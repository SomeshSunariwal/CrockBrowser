package com.browser.crockbrowser.browser;

import android.os.SystemClock;
import android.view.MotionEvent;
import android.webkit.WebView;
import androidx.webkit.ScriptHandler;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import java.net.URI;
import java.util.Locale;
import java.util.Set;
import java.util.function.BooleanSupplier;
import org.json.JSONObject;

/** Automatically activates an available YouTube Skip control, without altering ad delivery. */
final class YouTubeAdSkipper {
  private static final Set<String> ORIGINS =
      Set.of(
          "https://youtube.com",
          "https://www.youtube.com",
          "https://m.youtube.com",
          "https://music.youtube.com");
  private final WebView view;
  private final BooleanSupplier active;
  private ScriptHandler documentScript;
  private boolean enabled;
  private boolean disposed;
  private long lastSkip;

  YouTubeAdSkipper(WebView view, BooleanSupplier active) {
    this.view = view;
    this.active = active;
    if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))
      WebViewCompat.addWebMessageListener(
          view,
          "crockYouTubeAdSkip",
          ORIGINS,
          (webView, message, origin, mainFrame, reply) -> {
            if (disposed
                || !enabled
                || !mainFrame
                || !active.getAsBoolean()
                || message.getType() != androidx.webkit.WebMessageCompat.TYPE_STRING
                || !"skip".equals(message.getData())
                || !youtube(origin.toString())
                || !youtube(view.getUrl())
                || !origin.getHost().equals(URI.create(view.getUrl()).getHost())
                || SystemClock.elapsedRealtime() - lastSkip < 1000) return;
            lastSkip = SystemClock.elapsedRealtime();
            String requestedPage = view.getUrl();
            // No webpage-supplied coordinates: independently locate an unoccluded ad-only control.
            view.evaluateJavascript(
                SKIP_TARGET,
                result -> {
                  if (disposed
                      || !enabled
                      || !active.getAsBoolean()
                      || !view.isShown()
                      || !requestedPage.equals(view.getUrl())) return;
                  try {
                    JSONObject point = new JSONObject(result);
                    double x = point.getDouble("x"), y = point.getDouble("y");
                    if (!Double.isFinite(x)
                        || !Double.isFinite(y)
                        || x <= 0
                        || x >= 1
                        || y <= 0
                        || y >= 1) return;
                    long now = SystemClock.uptimeMillis();
                    MotionEvent down =
                        MotionEvent.obtain(
                            now,
                            now,
                            MotionEvent.ACTION_DOWN,
                            (float) (x * view.getWidth()),
                            (float) (y * view.getHeight()),
                            0);
                    MotionEvent up =
                        MotionEvent.obtain(
                            now,
                            now,
                            MotionEvent.ACTION_UP,
                            (float) (x * view.getWidth()),
                            (float) (y * view.getHeight()),
                            0);
                    down.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);
                    up.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);
                    try {
                      view.dispatchTouchEvent(down);
                      view.dispatchTouchEvent(up);
                    } finally {
                      down.recycle();
                      up.recycle();
                    }
                  } catch (Exception ignored) {
                    // The ad may have ended while its control was being checked.
                  }
                });
          });
  }

  void setEnabled(boolean next) {
    if (next == enabled) return;
    enabled = next;
    if (next) {
      if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT))
        documentScript = WebViewCompat.addDocumentStartJavaScript(view, SCRIPT, ORIGINS);
      finished();
    } else {
      if (documentScript != null) {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT))
          documentScript.remove();
        documentScript = null;
      }
      view.evaluateJavascript("window.__crockYouTubeAdSkip?.stop()", null);
    }
  }

  void finished() {
    if (enabled && youtube(view.getUrl())) view.evaluateJavascript(SCRIPT, null);
  }

  static boolean youtube(String url) {
    try {
      URI uri = URI.create(url);
      return "https".equalsIgnoreCase(uri.getScheme())
          && uri.getUserInfo() == null
          && (uri.getPort() == -1 || uri.getPort() == 443)
          && uri.getHost() != null
          && Set.of("youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com")
              .contains(uri.getHost().toLowerCase(Locale.ROOT));
    } catch (RuntimeException error) {
      return false;
    }
  }

  void dispose() {
    disposed = true;
    setEnabled(false);
    if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))
      WebViewCompat.removeWebMessageListener(view, "crockYouTubeAdSkip");
  }

  static final String SKIP_TARGET =
      """
      (() => {
        if (document.visibilityState !== 'visible' || window.__crockMediaActive === false) return null;
        const selector = '.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-skip-ad-button,.ytm-ad-skip-button,.ytp-ad-skip-button-slot button';
        for (const player of document.querySelectorAll('.ad-showing,.ad-interrupting')) {
          for (const button of player.querySelectorAll(selector)) {
            if (button.disabled || button.hidden || button.getAttribute('aria-disabled') === 'true') continue;
            const rect = button.getBoundingClientRect(), css = getComputedStyle(button);
            const x = rect.left + rect.width / 2, y = rect.top + rect.height / 2;
            if (!rect.width || !rect.height || css.display === 'none' || css.visibility !== 'visible' || Number(css.opacity) <= 0) continue;
            if (!button.contains(document.elementFromPoint(x,y))) continue;
            return {x:x/innerWidth,y:y/innerHeight};
          }
        }
        return null;
      })()
      """;

  static final String SCRIPT =
      """
      (() => {
        if (window !== window.top || location.protocol !== 'https:' ||
            !['youtube.com','www.youtube.com','m.youtube.com','music.youtube.com'].includes(location.hostname)) return false;
        if (window.__crockYouTubeAdSkip) { window.__crockYouTubeAdSkip.refresh(); return true; }
        const skip = '.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-skip-ad-button,' +
          '.ytm-ad-skip-button,.ytp-ad-skip-button-slot button';
        const clicked = new WeakMap();
        let stopped = false, pending = 0;
        const visible = el => {
          if (!el.isConnected || el.hidden || !el.getClientRects().length) return false;
          const css = getComputedStyle(el);
          return css.display !== 'none' && css.visibility === 'visible' && Number(css.opacity) > 0;
        };
        const tick = () => {
          pending = 0;
          if (stopped || document.visibilityState !== 'visible' || window.__crockMediaActive === false) return;
          for (const player of document.querySelectorAll('.ad-showing,.ad-interrupting')) {
            for (const button of player.querySelectorAll(skip)) {
              if (!visible(button) || button.disabled || button.getAttribute('aria-disabled') === 'true') continue;
              const now = performance.now();
              if (now - (clicked.get(button) ?? -1000) < 1000) continue;
              clicked.set(button, now);
              if (window.crockYouTubeAdSkip) window.crockYouTubeAdSkip.postMessage('skip');
              else button.click();
              break;
            }
          }
        };
        const schedule = () => { if (!stopped && !pending) pending = setTimeout(tick, 60); };
        const observer = new MutationObserver(schedule);
        observer.observe(document, {childList:true,subtree:true,attributes:true,
          attributeFilter:['class','style','disabled','aria-disabled']});
        const timer = setInterval(schedule, 500);
        const stop = () => {
          if (stopped) return;
          stopped = true;
          observer.disconnect(); clearInterval(timer); clearTimeout(pending);
          removeEventListener('yt-navigate-finish',schedule);
          removeEventListener('yt-page-data-updated',schedule);
          document.removeEventListener('visibilitychange',schedule);
          delete window.__crockYouTubeAdSkip;
        };
        addEventListener('yt-navigate-finish',schedule);
        addEventListener('yt-page-data-updated',schedule);
        document.addEventListener('visibilitychange',schedule);
        window.__crockYouTubeAdSkip = {refresh:schedule,stop};
        schedule();
        return true;
      })()
      """;
}
