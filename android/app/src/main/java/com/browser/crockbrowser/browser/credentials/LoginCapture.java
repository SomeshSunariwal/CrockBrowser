package com.browser.crockbrowser.browser.credentials;

import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.webkit.WebView;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import com.browser.crockbrowser.PrivateBrowserActivity;
import com.browser.crockbrowser.core.HostChannel;
import com.browser.crockbrowser.core.JsonCodec;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.json.JSONObject;

/** Main-frame, origin-verified login candidates. Secrets expire in memory and need user consent. */
public final class LoginCapture {
  private final HostChannel host;
  private final WebView view;
  private final int viewId;
  private final Handler main = new Handler(Looper.getMainLooper());
  private final Set<String> excluded = new HashSet<>();
  private final boolean supported;
  private boolean enabled = true, disposed;
  private Candidate pending;
  private int checks;
  private final Runnable validate = this::validate;
  private final Runnable expire = this::clear;

  private static final class Candidate {
    String origin, page, username, password;
    long created;
    boolean navigated;
  }

  public LoginCapture(HostChannel host, WebView view, int viewId) {
    this.host = host;
    this.view = view;
    this.viewId = viewId;
    supported =
        !(host.activity instanceof PrivateBrowserActivity)
            && WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER);
    if (supported && WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
      WebViewCompat.addWebMessageListener(
          view,
          "crockLoginEvents",
          Set.of("*"),
          (webView, message, sourceOrigin, isMainFrame, reply) -> {
            if (!enabled
                || disposed
                || !isMainFrame
                || !allowed(sourceOrigin)
                || !origin(sourceOrigin).equals(origin(Uri.parse(currentUrl())))) return;
            String data = message.getData();
            if (data == null || data.length() > 8192 || excluded.contains(origin(sourceOrigin)))
              return;
            try {
              JSONObject payload = new JSONObject(data);
              if ("submitted".equals(payload.optString("type"))) {
                String password = payload.optString("password");
                String username = payload.optString("username");
                if (password.isEmpty() || password.length() > 4096 || username.length() > 512)
                  return;
                clear();
                pending = new Candidate();
                pending.origin = origin(sourceOrigin);
                pending.page = currentUrl();
                pending.username = username;
                pending.password = password;
                pending.created = SystemClock.elapsedRealtime();
                main.postDelayed(expire, 60000);
                schedule();
              } else if ("check".equals(payload.optString("type"))) schedule();
            } catch (Exception ignored) {
              /* Never log form data. */
            }
          });
    }
  }

  public void configure(Map<String, Object> options) {
    if (options.containsKey("offerSavePasswords"))
      enabled = Boolean.TRUE.equals(options.get("offerSavePasswords"));
    if (options.get("passwordPromptBlockedOrigins") instanceof List<?> blocked) {
      excluded.clear();
      for (Object entry : blocked) if (entry instanceof String) excluded.add((String) entry);
    }
    if (!enabled || (pending != null && excluded.contains(pending.origin))) clear();
    if (!supported) return;
    if (enabled && allowed(Uri.parse(currentUrl()))) install();
    else view.evaluateJavascript("window.__crockLoginCaptureEnabled=false", null);
  }

  public void started(String url) {
    if (pending == null) return;
    if (!pending.origin.equals(origin(Uri.parse(url)))) clear();
    else if (!pending.page.equals(url)) pending.navigated = true;
  }

  public void finished() {
    if (supported && enabled && allowed(Uri.parse(currentUrl()))) install();
    schedule();
  }

  private void install() {
    if (excluded.contains(origin(Uri.parse(currentUrl())))) return;
    view.evaluateJavascript(LoginScripts.INSTALL, null);
  }

  private void schedule() {
    if (pending == null || checks >= 12 || disposed || !enabled) return;
    if (!main.hasCallbacks(validate)) main.postDelayed(validate, 1600);
  }

  private void validate() {
    Candidate candidate = pending;
    if (candidate == null || disposed) return;
    if (SystemClock.elapsedRealtime() - candidate.created > 60000
        || !candidate.origin.equals(origin(Uri.parse(currentUrl())))) {
      clear();
      return;
    }
    checks++;
    view.evaluateJavascript(
        LoginScripts.success(candidate.navigated),
        result -> {
          if (pending != candidate || disposed || !enabled) return;
          if ("true".equals(result) && candidate.origin.equals(origin(Uri.parse(currentUrl())))) {
            host.emit(
                JsonCodec.map(
                    "type",
                    "loginSuggestion",
                    "view",
                    viewId,
                    "origin",
                    candidate.origin,
                    "username",
                    candidate.username,
                    "password",
                    candidate.password));
            clear();
          } else schedule();
        });
  }

  public void clear() {
    pending = null;
    checks = 0;
    main.removeCallbacks(validate);
    main.removeCallbacks(expire);
  }

  public void dispose() {
    disposed = true;
    clear();
    if (supported && WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
      WebViewCompat.removeWebMessageListener(view, "crockLoginEvents");
    }
  }

  private String currentUrl() {
    return view.getUrl() == null ? "about:blank" : view.getUrl();
  }

  private boolean allowed(Uri uri) {
    if ("https".equalsIgnoreCase(uri.getScheme()) && uri.getHost() != null) return true;
    // Local synthetic pages are allowed only in a debuggable development build.
    boolean debug =
        (host.activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
    return debug
        && "http".equals(uri.getScheme())
        && ("127.0.0.1".equals(uri.getHost()) || "localhost".equals(uri.getHost()));
  }

  private static String origin(Uri uri) {
    if (uri.getScheme() == null || uri.getHost() == null) return "";
    String scheme = uri.getScheme().toLowerCase(Locale.ROOT);
    int port = uri.getPort();
    boolean standard =
        port == -1
            || (scheme.equals("https") && port == 443)
            || (scheme.equals("http") && port == 80);
    return scheme + "://" + uri.getHost().toLowerCase(Locale.ROOT) + (standard ? "" : ":" + port);
  }
}
