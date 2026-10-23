package com.example.crocbrowser;

import android.content.Intent;
import com.example.crocbrowser.browser.BrowserViewFactory;
import com.example.crocbrowser.core.HostChannel;
import com.example.crocbrowser.core.JsonCodec;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

/** Thin Flutter host. Java feature services are behind croc/native and platform views. */
public class MainActivity extends FlutterActivity {
  private HostChannel host;

  @Override
  public void configureFlutterEngine(FlutterEngine engine) {
    super.configureFlutterEngine(engine);
    host = new HostChannel(this, engine.getDartExecutor().getBinaryMessenger());
    engine
        .getPlatformViewsController()
        .getRegistry()
        .registerViewFactory("croc/webview", new BrowserViewFactory(host));
  }

  @Override
  public String getInitialRoute() {
    return getIntent().getBooleanExtra("openDownloads", false) ? "/downloads" : "/";
  }

  @Override
  protected void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    setIntent(intent);
    if (host != null && intent.getBooleanExtra("openDownloads", false))
      host.emit(JsonCodec.map("type", "navigate", "screen", "downloads"));
  }

  @Override
  protected void onActivityResult(int request, int result, Intent data) {
    super.onActivityResult(request, result, data);
    if (host != null) host.onActivityResult(request, result, data);
  }

  @Override
  public void onRequestPermissionsResult(int request, String[] permissions, int[] grants) {
    super.onRequestPermissionsResult(request, permissions, grants);
    if (host != null) host.onPermissions(request, permissions, grants);
  }

  private boolean fullscreenBackRegistered;
  private final android.window.OnBackInvokedCallback fullscreenBack =
      () -> {
        if (host != null) host.hideFullscreen();
      };

  public void handleFullscreenBack(boolean enabled) {
    if (enabled && !fullscreenBackRegistered) {
      getOnBackInvokedDispatcher()
          .registerOnBackInvokedCallback(
              android.window.OnBackInvokedDispatcher.PRIORITY_OVERLAY, fullscreenBack);
      fullscreenBackRegistered = true;
    } else if (!enabled && fullscreenBackRegistered) {
      getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(fullscreenBack);
      fullscreenBackRegistered = false;
    }
  }

  @Override
  protected void onDestroy() {
    handleFullscreenBack(false);
    if (host != null) host.dispose();
    super.onDestroy();
  }
}
