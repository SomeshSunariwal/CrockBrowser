package com.example.crocbrowser.core;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.view.WindowManager;
import com.example.crocbrowser.MainActivity;
import java.util.Map;

public final class DeviceBridge {
  private final MainActivity activity;

  public DeviceBridge(MainActivity activity) {
    this.activity = activity;
  }

  public Object handle(String method, Map<String, Object> args) throws Exception {
    switch (method) {
      case "device.brightness":
        WindowManager.LayoutParams p = activity.getWindow().getAttributes();
        p.screenBrightness = ((Number) args.getOrDefault("value", -1)).floatValue();
        activity.getWindow().setAttributes(p);
        return null;
      case "device.rotation":
        String mode = JsonCodec.string(args, "value", "auto");
        activity.setRequestedOrientation(
            mode.equals("portrait")
                ? ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT
                : mode.equals("landscape")
                    ? ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE
                    : ActivityInfo.SCREEN_ORIENTATION_FULL_USER);
        return null;
      case "clipboard.read":
        ClipboardManager clipboard = activity.getSystemService(ClipboardManager.class);
        return clipboard.hasPrimaryClip()
            ? clipboard.getPrimaryClip().getItemAt(0).coerceToText(activity).toString()
            : "";
      case "clipboard.write":
        activity
            .getSystemService(ClipboardManager.class)
            .setPrimaryClip(
                ClipData.newPlainText("Crock Browser", JsonCodec.string(args, "text", "")));
        return null;
      case "device.share":
        activity.startActivity(
            Intent.createChooser(
                new Intent(Intent.ACTION_SEND)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, JsonCodec.string(args, "text", "")),
                "Share from Crock Browser"));
        return null;
      default:
        throw new IllegalArgumentException("Unknown device command");
    }
  }
}
