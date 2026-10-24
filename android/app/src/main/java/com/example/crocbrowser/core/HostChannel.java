package com.example.crocbrowser.core;

import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.webkit.*;
import android.widget.FrameLayout;
import com.example.crocbrowser.*;
import com.example.crocbrowser.downloads.*;
import com.example.crocbrowser.files.FilesBridge;
import com.example.crocbrowser.media.MediaPlayerActivity;
import com.example.crocbrowser.reading.TranslationBridge;
import com.example.crocbrowser.security.VaultBridge;
import com.google.zxing.integration.android.IntentIntegrator;
import com.google.zxing.integration.android.IntentResult;
import io.flutter.plugin.common.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import org.json.*;

/** The single platform entry point. Feature services own their own implementation. */
public final class HostChannel implements MethodChannel.MethodCallHandler {
  public final MainActivity activity;
  public final BinaryMessenger messenger;
  private final EncryptedStore store;
  private final FilesBridge files;
  private final VaultBridge vault;
  private final DeviceBridge device;
  private final DownloadRepository downloads;
  private final ExecutorService io = Executors.newSingleThreadExecutor();
  private final Handler main = new Handler(Looper.getMainLooper());
  private EventChannel.EventSink sink;
  private Map<String, Object> pendingNavigation;
  private MethodChannel.Result scanResult, permissionResult;
  private ValueCallback<Uri[]> fileCallback;
  private PermissionRequest sitePermission;
  private View fullscreen;
  private WebChromeClient.CustomViewCallback fullscreenCallback;
  private final boolean privateMode;
  private final BroadcastReceiver downloadReceiver =
      new BroadcastReceiver() {
        @Override
        public void onReceive(Context c, Intent i) {
          emit(JsonCodec.map("type", "downloads", "error", i.getStringExtra("error"),
              "tasksJson", i.getStringExtra("tasks"), "requestId", i.getStringExtra("requestId")));
        }
      };

  public HostChannel(MainActivity activity, BinaryMessenger messenger) {
    this.activity = activity;
    this.messenger = messenger;
    privateMode = activity instanceof PrivateBrowserActivity;
    store = new EncryptedStore(activity);
    files = new FilesBridge(activity);
    vault = new VaultBridge(activity, files);
    device = new DeviceBridge(activity);
    downloads = new DownloadRepository(activity);
    new MethodChannel(messenger, "croc/native").setMethodCallHandler(this);
    new EventChannel(messenger, "croc/events")
        .setStreamHandler(
            new EventChannel.StreamHandler() {
              @Override
              public void onListen(Object arguments, EventChannel.EventSink events) {
                sink = events;
                if (pendingNavigation != null) {
                  sink.success(pendingNavigation);
                  pendingNavigation = null;
                }
              }

              @Override
              public void onCancel(Object arguments) {
                sink = null;
              }
            });
    activity.registerReceiver(
        downloadReceiver, new IntentFilter(DownloadService.EVENT), Context.RECEIVER_NOT_EXPORTED);
  }

  public void emit(Map<String, Object> event) {
    main.post(
        () -> {
          if (sink != null) sink.success(event);
          else if ("navigate".equals(event.get("type"))) pendingNavigation = event;
        });
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    Map<String, Object> args =
        call.arguments instanceof Map ? (Map<String, Object>) call.arguments : new HashMap<>();
    try {
      String method = call.method;
      if (method.equals("store.read")) {
        result.success(store.read("browser", "{}"));
        return;
      }
      if (method.equals("store.write")) {
        JSONObject next = new JSONObject(JsonCodec.string(args, "json", "{}"));
        store.update(
            "browser",
            current -> {
              JSONObject previous = new JSONObject(current);
              List<String> keys = (List<String>) args.getOrDefault("keys", Collections.emptyList());
              for (String key : keys) {
                if (privateMode && (key.equals("tabs") || key.equals("history"))) continue;
                if (next.has(key)) previous.put(key, next.get(key));
              }
              JSONObject settings = previous.optJSONObject("settings");
              if (settings == null) settings = new JSONObject();
              JSONObject updated = next.optJSONObject("settings");
              for (String key :
                  (List<String>) args.getOrDefault("settingsKeys", Collections.emptyList()))
                if (updated != null && updated.has(key)) settings.put(key, updated.get(key));
              previous.put("settings", settings);
              return previous.toString();
            });
        result.success(null);
        return;
      }
      if (method.equals("private.open")) {
        if (!privateMode)
          activity.startActivity(new Intent(activity, PrivateBrowserActivity.class));
        result.success(null);
        return;
      }
      if (method.equals("private.close")) {
        if (privateMode) activity.finish();
        result.success(null);
        return;
      }
      if (method.equals("device.permissions")) {
        requestPermissions(args, result);
        return;
      }
      if (method.startsWith("device.") || method.startsWith("clipboard.")) {
        result.success(device.handle(method, args));
        return;
      }
      if (method.equals("qr.scan")) {
        if (scanResult != null) throw new IOException("Scanner is already open");
        scanResult = result;
        new IntentIntegrator(activity)
            .setPrompt("Scan a QR code or barcode with Crock Browser")
            .setBeepEnabled(false)
            .setOrientationLocked(false)
            .initiateScan();
        return;
      }
      if (method.equals("browser.clearData")) {
        CookieManager.getInstance().removeAllCookies(value -> CookieManager.getInstance().flush());
        WebStorage.getInstance().deleteAllData();
        result.success(null);
        return;
      }
      if (method.equals("blocking.clear")) {
        store.write("hidden_elements", "{}");
        result.success(null);
        return;
      }
      if (method.equals("translate")) {
        TranslationBridge.translate(args, result);
        return;
      }
      if (method.equals("vault.unlock")) {
        vault.unlock(result);
        return;
      }
      if (method.startsWith("vault.")
          || method.startsWith("passwords.")
          || method.startsWith("profiles.")) {
        async(result, () -> vault.handle(method, args));
        return;
      }
      if (method.equals("files.pickFolder")
          || method.equals("files.import")
          || method.equals("files.pickText")
          || method.equals("files.export")
          || method.equals("files.exportText")) {
        files.pick(method, args, result);
        return;
      }
      if (method.equals("files.open") || method.equals("files.share")) {
        result.success(files.handle(method, args));
        return;
      }
      if (method.startsWith("files.")) {
        async(result, () -> files.handle(method, args));
        return;
      }
      if (method.equals("media.play")) {
        String path = JsonCodec.string(args, "path", "");
        Uri uri =
            path.isEmpty()
                ? Uri.parse(JsonCodec.string(args, "uri", ""))
                : androidx.core.content.FileProvider.getUriForFile(
                    activity, activity.getPackageName() + ".files", files.allowed(path));
        activity.startActivity(
            new Intent(activity, MediaPlayerActivity.class)
                .setData(uri)
                .putExtra("downloadId", (String) args.get("downloadId"))
                .putExtra(
                    "headers",
                    new JSONObject((Map) args.getOrDefault("headers", Collections.emptyMap()))
                        .toString())
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION));
        result.success(null);
        return;
      }
      if (method.equals("downloads.list")) {
        async(result, downloads::snapshot);
        return;
      }
      if (method.equals("downloads.settings")) {
        if (args.containsKey("concurrency"))
          activity
              .getSharedPreferences("transfer_options", 0)
              .edit()
              .putInt("concurrency", JsonCodec.integer(args, "concurrency", 3))
              .putBoolean("wifiOnly", Boolean.TRUE.equals(args.get("wifiOnly")))
              .apply();
        result.success(
            JsonCodec.map(
                "concurrency",
                activity.getSharedPreferences("transfer_options", 0).getInt("concurrency", 3),
                "wifiOnly",
                activity
                    .getSharedPreferences("transfer_options", 0)
                    .getBoolean("wifiOnly", false)));
        return;
      }
      if (method.equals("downloads.enqueue") || method.equals("downloads.command")) {
        Intent intent =
            new Intent(activity, DownloadService.class)
                .putExtra(
                    "action",
                    method.equals("downloads.enqueue")
                        ? "enqueue"
                        : JsonCodec.string(args, "action", ""));
        if (method.equals("downloads.enqueue"))
          intent.putExtra("request", new JSONObject(args).toString());
        else intent.putExtra("id", JsonCodec.string(args, "id", ""));
        activity.startForegroundService(intent);
        result.success(true);
        return;
      }
      if (method.equals("downloads.file")) {
        for (DownloadTask task : downloads.load())
          if (task.id.equals(args.get("id"))) {
            File file = task.completed(downloads.root);
            result.success(
                JsonCodec.map(
                    "path",
                    file.getPath(),
                    "exists",
                    task.stream() ? task.state.equals("complete") : file.exists(),
                    "name",
                    task.name,
                    "mime",
                    task.mime,
                    "stream",
                    task.stream(),
                    "torrent",
                    task.torrent(),
                    "url",
                    task.url));
            return;
          }
        throw new FileNotFoundException("Download not found");
      }
      if (method.equals("offline.list")) {
        result.success(JsonCodec.unwrap(new JSONArray(store.read("offline", "[]"))));
        return;
      }
      if (method.equals("offline.remove")) {
        JSONArray rows = new JSONArray(store.read("offline", "[]"));
        String id = JsonCodec.string(args, "id", "");
        for (int i = rows.length() - 1; i >= 0; i--)
          if (rows.getJSONObject(i).optString("id").equals(id)) {
            String path = rows.getJSONObject(i).optString("path");
            if (isOfflinePath(path)) new File(path).delete();
            rows.remove(i);
          }
        store.write("offline", rows.toString());
        result.success(null);
        return;
      }
      result.notImplemented();
    } catch (Exception error) {
      result.error("CROC", error.getMessage(), null);
    }
  }

  private void async(MethodChannel.Result result, Callable<Object> operation) {
    io.execute(
        () -> {
          try {
            Object value = operation.call();
            main.post(() -> result.success(value));
          } catch (Exception error) {
            main.post(() -> result.error("CROC", error.getMessage(), null));
          }
        });
  }

  private void requestPermissions(Map<String, Object> args, MethodChannel.Result result) {
    List<String> requested = (List<String>) args.get("permissions");
    if (requested != null) requested = new ArrayList<>(requested);
    if (android.os.Build.VERSION.SDK_INT >= 34
        && requested != null
        && (requested.contains(android.Manifest.permission.READ_MEDIA_IMAGES)
            || requested.contains(android.Manifest.permission.READ_MEDIA_VIDEO)))
      requested.add(android.Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED);
    List<String> missing = new ArrayList<>();
    if (requested != null)
      for (String permission : requested)
        if (activity.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED)
          missing.add(permission);
    if (missing.isEmpty()) {
      result.success(true);
      return;
    }
    if (permissionResult != null) {
      result.error("PERMISSION", "Finish the current permission request first", null);
      return;
    }
    permissionResult = result;
    activity.requestPermissions(missing.toArray(new String[0]), 703);
  }

  public void onPermissions(int request, String[] permissions, int[] grants) {
    if (request == 703 && permissionResult != null) {
      boolean granted = grants.length > 0;
      for (int result : grants) granted &= result == PackageManager.PERMISSION_GRANTED;
      boolean mediaRequest = false, anyMedia = false;
      for (int index = 0; index < permissions.length && index < grants.length; index++) {
        if (permissions[index].contains("READ_MEDIA_")) {
          mediaRequest = true;
          anyMedia |= grants[index] == PackageManager.PERMISSION_GRANTED;
        }
      }
      permissionResult.success(mediaRequest ? anyMedia : granted);
      permissionResult = null;
    }
    if (request == 704 && sitePermission != null) {
      boolean granted = grants.length > 0;
      for (int result : grants) granted &= result == PackageManager.PERMISSION_GRANTED;
      if (granted) sitePermission.grant(sitePermission.getResources());
      else sitePermission.deny();
      sitePermission = null;
    }
  }

  public void askWebsitePermission(PermissionRequest request) {
    activity.runOnUiThread(
        () -> {
          if (sitePermission != null) {
            request.deny();
            return;
          }
          new AlertDialog.Builder(activity)
              .setTitle("Website permission")
              .setMessage(request.getOrigin() + " wants camera or microphone access.")
              .setNegativeButton("Deny", (d, w) -> request.deny())
              .setOnCancelListener(d -> request.deny())
              .setPositiveButton(
                  "Allow",
                  (d, w) -> {
                    List<String> permissions = new ArrayList<>();
                    for (String resource : request.getResources()) {
                      if (resource.equals(PermissionRequest.RESOURCE_VIDEO_CAPTURE))
                        permissions.add(android.Manifest.permission.CAMERA);
                      else if (resource.equals(PermissionRequest.RESOURCE_AUDIO_CAPTURE))
                        permissions.add(android.Manifest.permission.RECORD_AUDIO);
                      else {
                        request.deny();
                        return;
                      }
                    }
                    sitePermission = request;
                    activity.requestPermissions(permissions.toArray(new String[0]), 704);
                  })
              .show();
        });
  }

  public void chooseWebFiles(
      ValueCallback<Uri[]> callback, WebChromeClient.FileChooserParams params) {
    if (fileCallback != null) fileCallback.onReceiveValue(null);
    fileCallback = callback;
    try {
      activity.startActivityForResult(params.createIntent(), 705);
    } catch (Exception error) {
      callback.onReceiveValue(null);
      fileCallback = null;
    }
  }

  public boolean onActivityResult(int request, int code, Intent data) {
    if (files.onResult(request, code, data) || vault.onResult(request, code)) return true;
    if (request == 705) {
      if (fileCallback != null)
        fileCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(code, data));
      fileCallback = null;
      return true;
    }
    IntentResult scan = IntentIntegrator.parseActivityResult(request, code, data);
    if (scan != null && scanResult != null) {
      scanResult.success(scan.getContents());
      scanResult = null;
      return true;
    }
    return false;
  }

  public void saveOffline(WebView view, MethodChannel.Result result) {
    File root = new File(activity.getFilesDir(), "offline");
    root.mkdirs();
    String id = UUID.randomUUID().toString();
    File destination = new File(root, id + ".mht");
    String title = view.getTitle(), url = view.getUrl();
    view.saveWebArchive(
        destination.getPath(),
        false,
        path -> {
          try {
            if (path == null) throw new IOException("This page could not be saved offline");
            JSONArray rows = new JSONArray(store.read("offline", "[]"));
            JSONObject entry =
                new JSONObject(
                    JsonCodec.map(
                        "id",
                        id,
                        "title",
                        title,
                        "url",
                        url,
                        "path",
                        path,
                        "created",
                        System.currentTimeMillis()));
            rows.put(entry);
            store.write("offline", rows.toString());
            result.success(JsonCodec.unwrap(entry));
          } catch (Exception error) {
            result.error("OFFLINE", error.getMessage(), null);
          }
        });
  }

  public boolean isOfflinePath(String path) {
    try {
      if (path == null) return false;
      return new File(path)
          .getCanonicalPath()
          .startsWith(
              new File(activity.getFilesDir(), "offline").getCanonicalPath() + File.separator);
    } catch (Exception error) {
      return false;
    }
  }

  public void saveHiddenElement(WebView view, String selector) {
    try {
      Uri uri = Uri.parse(view.getUrl());
      JSONObject hidden = new JSONObject(store.read("hidden_elements", "{}"));
      JSONArray rules = hidden.optJSONArray(uri.getHost());
      if (rules == null) rules = new JSONArray();
      rules.put(selector);
      hidden.put(uri.getHost(), rules);
      store.write("hidden_elements", hidden.toString());
      emit(JsonCodec.map("type", "message", "text", "Element hidden on this site"));
    } catch (Exception error) {
      emit(JsonCodec.map("type", "message", "text", error.getMessage()));
    }
  }

  public void applyHiddenElements(WebView view) {
    try {
      JSONObject hidden = new JSONObject(store.read("hidden_elements", "{}"));
      JSONArray rules = hidden.optJSONArray(Uri.parse(view.getUrl()).getHost());
      if (rules != null)
        view.evaluateJavascript(
            "(()=>{const rules="
                + rules
                + ";for(const rule of"
                + " rules){try{document.querySelectorAll(rule).forEach(el=>el.style.setProperty('display','none','important'));}catch(e){}}})()",
            null);
    } catch (Exception ignored) {
    }
  }

  public void showFullscreen(View view, WebChromeClient.CustomViewCallback callback) {
    if (fullscreen != null) {
      callback.onCustomViewHidden();
      return;
    }
    activity.handleFullscreenBack(true);
    fullscreen = view;
    fullscreenCallback = callback;
    ((FrameLayout) activity.getWindow().getDecorView())
        .addView(view, new FrameLayout.LayoutParams(-1, -1));
  }

  public void hideFullscreen() {
    activity.handleFullscreenBack(false);
    if (fullscreen != null) {
      ((FrameLayout) activity.getWindow().getDecorView()).removeView(fullscreen);
      fullscreen = null;
      if (fullscreenCallback != null) fullscreenCallback.onCustomViewHidden();
      fullscreenCallback = null;
    }
  }

  public boolean hasFullscreen() {
    return fullscreen != null;
  }

  public void dispose() {
    activity.unregisterReceiver(downloadReceiver);
    vault.lock();
    io.shutdown();
    sink = null;
  }
}
