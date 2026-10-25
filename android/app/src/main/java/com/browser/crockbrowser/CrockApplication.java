package com.browser.crockbrowser;

import android.app.Application;
import android.webkit.WebView;
import java.io.File;

/** A separate process and profile prevents private tabs sharing normal cookies/storage. */
public class CrockApplication extends Application {
  @Override
  public void onCreate() {
    super.onCreate();
    if (Application.getProcessName().endsWith(":private")) {
      File profile = new File(getApplicationInfo().dataDir, "app_webview_croc_private");
      deleteProfile(profile, profile);
      WebView.setDataDirectorySuffix("croc_private");
    }
  }

  private void deleteProfile(File file, File root) {
    try {
      if (!file.getCanonicalPath().startsWith(root.getCanonicalPath() + File.separator)
          && !file.equals(root)) return;
      File[] children = file.listFiles();
      if (children != null) for (File child : children) deleteProfile(child, root);
      file.delete();
    } catch (Exception ignored) {
    }
  }
}
