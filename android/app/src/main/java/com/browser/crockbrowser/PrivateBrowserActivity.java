package com.browser.crockbrowser;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.WebStorage;

public final class PrivateBrowserActivity extends MainActivity {
  @Override
  public String getInitialRoute() {
    return "/private";
  }

  @Override
  protected void onCreate(Bundle state) {
    super.onCreate(state);
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
  }

  @Override
  public void finish() {
    CookieManager.getInstance().removeAllCookies(null);
    WebStorage.getInstance().deleteAllData();
    super.finish();
    new Handler(Looper.getMainLooper())
        .postDelayed(() -> android.os.Process.killProcess(android.os.Process.myPid()), 300);
  }
}
