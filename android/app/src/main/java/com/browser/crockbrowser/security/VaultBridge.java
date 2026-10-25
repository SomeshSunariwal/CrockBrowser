package com.browser.crockbrowser.security;

import android.app.Activity;
import android.app.KeyguardManager;
import android.content.Intent;
import android.os.SystemClock;
import com.browser.crockbrowser.MainActivity;
import com.browser.crockbrowser.core.EncryptedStore;
import com.browser.crockbrowser.core.JsonCodec;
import com.browser.crockbrowser.files.FilesBridge;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Map;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONObject;

/** Device-credential-gated, encrypted local credentials and Private Space files. */
public final class VaultBridge {
  private final MainActivity activity;
  private final FilesBridge files;
  private final EncryptedStore store;
  private final File root;
  private long unlockedUntil;
  private MethodChannel.Result pending;

  public VaultBridge(MainActivity activity, FilesBridge files) {
    this.activity = activity;
    this.files = files;
    store = new EncryptedStore(activity);
    root = new File(activity.getNoBackupFilesDir(), "vault");
    root.mkdirs();
    lock();
  }

  private void requireUnlocked() {
    if (SystemClock.elapsedRealtime() > unlockedUntil)
      throw new SecurityException("Unlock Private Space first");
  }

  public void unlock(MethodChannel.Result result) {
    KeyguardManager lock = activity.getSystemService(KeyguardManager.class);
    if (!lock.isDeviceSecure()) {
      result.error("VAULT", "Set an Android screen lock before using Private Space", null);
      return;
    }
    if (pending != null) {
      result.error("VAULT", "An unlock request is already open", null);
      return;
    }
    pending = result;
    activity.startActivityForResult(
        lock.createConfirmDeviceCredentialIntent(
            "Unlock Crock Browser", "Confirm your device PIN, pattern or password"),
        702);
  }

  public boolean onResult(int request, int result) {
    if (request != 702) return false;
    if (pending != null) {
      if (result == Activity.RESULT_OK) {
        unlockedUntil = SystemClock.elapsedRealtime() + 5 * 60 * 1000;
        activity.getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);
        pending.success(true);
      } else pending.success(false);
      pending = null;
    }
    return true;
  }

  public void lock() {
    unlockedUntil = 0;
    activity.runOnUiThread(
        () -> {
          if (!(activity instanceof com.browser.crockbrowser.PrivateBrowserActivity))
            activity.getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);
        });
    File cache = new File(activity.getCacheDir(), "private-preview");
    File[] previews = cache.listFiles();
    if (previews != null) for (File preview : previews) preview.delete();
  }

  public Object handle(String method, Map<String, Object> args) throws Exception {
    if (method.equals("passwords.status")) {
      // Only trusted Flutter calls can query this; it returns no stored credentials.
      JSONArray saved = new JSONArray(store.read("passwords", "[]"));
      boolean exists = false, matches = false;
      for (int i = 0; i < saved.length(); i++) {
        JSONObject item = saved.getJSONObject(i);
        if (item.optString("origin").equals(JsonCodec.string(args, "origin", ""))
            && item.optString("username").equals(JsonCodec.string(args, "username", ""))) {
          exists = true;
          if (item.optString("password").equals(JsonCodec.string(args, "password", "")))
            matches = true;
        }
      }
      return JsonCodec.map("exists", exists, "matches", matches);
    }
    if (method.equals("vault.lock")) {
      lock();
      return null;
    }
    requireUnlocked();
    String type =
        method.startsWith("passwords.")
            ? "passwords"
            : method.startsWith("profiles.") ? "profiles" : "private_files";
    JSONArray rows = new JSONArray(store.read(type, "[]"));
    if (method.endsWith("list")) return JsonCodec.unwrap(rows);
    String id = JsonCodec.string(args, "id", UUID.randomUUID().toString());
    if (!id.matches("[A-Za-z0-9_-]{1,80}"))
      throw new IllegalArgumentException("Invalid saved item identifier");
    if ((method.equals("passwords.save") || method.equals("profiles.save"))) {
      JSONObject item = new JSONObject(args);
      item.put("id", id);
      for (int i = rows.length() - 1; i >= 0; i--)
        if (rows.getJSONObject(i).optString("id").equals(id)) rows.remove(i);
      rows.put(item);
      store.write(type, rows.toString());
      return null;
    }
    if (method.endsWith("delete")) {
      for (int i = rows.length() - 1; i >= 0; i--)
        if (rows.getJSONObject(i).optString("id").equals(id)) {
          if (type.equals("private_files")) new File(root, id + ".enc").delete();
          rows.remove(i);
        }
      store.write(type, rows.toString());
      return null;
    }
    if (method.equals("vault.import")) {
      File input = files.allowed(JsonCodec.string(args, "path", ""));
      File destination = new File(root, id + ".enc");
      store.encryptFile(input, destination);
      rows.put(
          new JSONObject(
              JsonCodec.map(
                  "id",
                  id,
                  "name",
                  JsonCodec.string(args, "name", input.getName()),
                  "size",
                  input.length(),
                  "mime",
                  FilesBridge.mime(input.getName()))));
      store.write(type, rows.toString());
      return null;
    }
    if (method.equals("vault.open")) {
      JSONObject entry = null;
      for (int i = 0; i < rows.length(); i++)
        if (rows.getJSONObject(i).optString("id").equals(id)) entry = rows.getJSONObject(i);
      if (entry == null) throw new FileNotFoundException("Private file not found");
      File encrypted = new File(root, id + ".enc");
      File temporary = new File(activity.getCacheDir(), "private-preview");
      temporary.mkdirs();
      File destination = new File(temporary, FilesBridge.safeName(entry.getString("name")));
      store.decryptFile(encrypted, destination);
      android.net.Uri uri =
          androidx.core.content.FileProvider.getUriForFile(
              activity, activity.getPackageName() + ".files", destination);
      activity.startActivity(
          Intent.createChooser(
              new Intent(Intent.ACTION_VIEW)
                  .setDataAndType(uri, entry.optString("mime", "application/octet-stream"))
                  .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
              "Open private file"));
      return null;
    }
    throw new IllegalArgumentException("Unknown vault command");
  }
}
