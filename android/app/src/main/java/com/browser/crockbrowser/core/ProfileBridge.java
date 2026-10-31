package com.browser.crockbrowser.core;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.ImageDecoder;
import android.net.Uri;
import com.browser.crockbrowser.MainActivity;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileOutputStream;
import java.util.UUID;
import java.util.concurrent.ExecutorService;

/** Imports only the selected photo, downsampled into app-private storage. */
final class ProfileBridge {
  private static final int PHOTO_REQUEST = 706;
  private final MainActivity activity;
  private final ExecutorService io;
  private MethodChannel.Result pending;

  ProfileBridge(MainActivity activity, ExecutorService io) {
    this.activity = activity;
    this.io = io;
  }

  void pick(MethodChannel.Result result) {
    if (pending != null) {
      result.error("PHOTO_BUSY", "Photo picker is already open", null);
      return;
    }
    pending = result;
    try {
      activity.startActivityForResult(
          new Intent(Intent.ACTION_GET_CONTENT).setType("image/*")
              .addCategory(Intent.CATEGORY_OPENABLE), PHOTO_REQUEST);
    } catch (Exception error) {
      pending = null;
      result.error("PHOTO_PICK", error.getMessage(), null);
    }
  }

  boolean onResult(int request, int code, Intent data) {
    if (request != PHOTO_REQUEST) return false;
    MethodChannel.Result result = pending;
    pending = null;
    if (result == null) return true;
    Uri uri = data == null ? null : data.getData();
    if (code != Activity.RESULT_OK || uri == null) {
      result.success(null);
      return true;
    }
    io.execute(() -> {
      File photo = null;
      try {
        Bitmap bitmap = ImageDecoder.decodeBitmap(
            ImageDecoder.createSource(activity.getContentResolver(), uri),
            (decoder, info, source) -> {
              int width = info.getSize().getWidth(), height = info.getSize().getHeight();
              float scale = Math.min(1f, 512f / Math.max(width, height));
              decoder.setTargetSize(Math.max(1, Math.round(width * scale)),
                  Math.max(1, Math.round(height * scale)));
              decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
            });
        File directory = new File(activity.getFilesDir(), "profile");
        if (!directory.exists() && !directory.mkdirs()) throw new java.io.IOException("Cannot save photo");
        photo = new File(directory, UUID.randomUUID() + ".png");
        try (FileOutputStream output = new FileOutputStream(photo)) {
          if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
            throw new java.io.IOException("Cannot encode photo");
        } finally {
          bitmap.recycle();
        }
        String path = photo.getAbsolutePath();
        activity.runOnUiThread(() -> result.success(path));
      } catch (Exception error) {
        if (photo != null) photo.delete();
        activity.runOnUiThread(() -> result.error("PHOTO_IMPORT", "Unable to open this photo", null));
      }
    });
    return true;
  }

  void dispose() {
    if (pending != null) pending.success(null);
    pending = null;
  }
}
