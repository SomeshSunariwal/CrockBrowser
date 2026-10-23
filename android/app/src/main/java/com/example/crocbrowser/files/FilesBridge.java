package com.example.crocbrowser.files;

import android.app.Activity;
import android.content.*;
import android.database.Cursor;
import android.net.Uri;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import androidx.core.content.FileProvider;
import com.example.crocbrowser.MainActivity;
import com.example.crocbrowser.core.JsonCodec;
import com.example.crocbrowser.downloads.DownloadRepository;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Scoped files and SAF operations. Arbitrary filesystem paths are never accepted. */
public final class FilesBridge {
  private final MainActivity activity;
  public final File root;
  private MethodChannel.Result pending;
  private String pendingAction;
  private File exportFile;

  public FilesBridge(MainActivity activity) {
    this.activity = activity;
    root = new DownloadRepository(activity).root;
  }

  public File allowed(String path) throws Exception {
    File file = new File(path).getCanonicalFile();
    if (!file.getPath().startsWith(root.getCanonicalPath() + File.separator) && !file.equals(root))
      throw new SecurityException("File is outside Crock downloads");
    return file;
  }

  public Object handle(String method, Map<String, Object> args) throws Exception {
    File file;
    switch (method) {
      case "files.bytes":
        String content = JsonCodec.string(args, "uri", "");
        try (InputStream input =
            content.isEmpty()
                ? new FileInputStream(allowed(JsonCodec.string(args, "path", "")))
                : activity.getContentResolver().openInputStream(Uri.parse(content))) {
          if (input == null) throw new IOException("Cannot open image");
          byte[] bytes = input.readNBytes(40 * 1024 * 1024 + 1);
          if (bytes.length > 40 * 1024 * 1024)
            throw new IOException("Image is too large for the preview; open it in another app");
          return bytes;
        }
      case "files.list":
        File directory = args.containsKey("path") ? allowed(args.get("path").toString()) : root;
        List<Map<String, Object>> rows = new ArrayList<>();
        File[] files = directory.listFiles();
        if (files != null)
          for (File item : files)
            if (!item.getName().startsWith(".extracting-")
                && !item.getName().endsWith(".part")
                && !item.getName().endsWith(".torrent-meta"))
              rows.add(
                  JsonCodec.map(
                      "name",
                      displayName(item.getName()),
                      "path",
                      item.getPath(),
                      "size",
                      item.length(),
                      "directory",
                      item.isDirectory(),
                      "mime",
                      mime(item.getName()),
                      "modified",
                      item.lastModified()));
        rows.sort(
            (a, b) ->
                Boolean.compare(
                    Boolean.TRUE.equals(b.get("directory")),
                    Boolean.TRUE.equals(a.get("directory"))));
        return rows;
      case "files.delete":
        file = allowed(JsonCodec.string(args, "path", ""));
        if (file.isDirectory()) throw new IOException("Open the folder and remove its files first");
        if (!file.delete()) throw new IOException("Cannot remove file");
        return null;
      case "files.rename":
        file = allowed(JsonCodec.string(args, "path", ""));
        String name = safeName(JsonCodec.string(args, "name", ""));
        if (file.getName().matches("^[a-f0-9-]{36}_.*"))
          name = file.getName().substring(0, 37) + name;
        File target = new File(file.getParentFile(), name);
        if (target.exists() || !file.renameTo(target))
          throw new IOException("Cannot rename file; the name may already exist");
        return target.getPath();
      case "files.open":
      case "files.share":
        file = allowed(JsonCodec.string(args, "path", ""));
        Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".files", file);
        Intent intent =
            method.equals("files.share")
                ? new Intent(Intent.ACTION_SEND)
                    .setType(mime(file.getName()))
                    .putExtra(Intent.EXTRA_STREAM, uri)
                : new Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime(file.getName()));
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        activity.startActivity(Intent.createChooser(intent, "Open from Crock Browser"));
        return null;
      case "files.extract":
        return ArchiveExtractor.extract(
            root,
            allowed(JsonCodec.string(args, "path", "")),
            JsonCodec.string(args, "password", ""));
      case "files.media":
        return media(JsonCodec.string(args, "kind", "video"));
      case "files.exportText":
        return null;
      default:
        throw new IllegalArgumentException("Unknown file command");
    }
  }

  public void pick(String method, Map<String, Object> args, MethodChannel.Result result)
      throws Exception {
    if (pending != null) throw new IOException("Finish the current file selection first");
    Intent intent;
    if (method.equals("files.pickFolder")) {
      intent =
          new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
              .addFlags(
                  Intent.FLAG_GRANT_READ_URI_PERMISSION
                      | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                      | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
    } else if (method.equals("files.export") || method.equals("files.exportText")) {
      intent =
          new Intent(Intent.ACTION_CREATE_DOCUMENT)
              .setType(JsonCodec.string(args, "mime", "application/octet-stream"))
              .addCategory(Intent.CATEGORY_OPENABLE)
              .putExtra(Intent.EXTRA_TITLE, JsonCodec.string(args, "name", "croc-export.html"));
      exportFile =
          method.equals("files.export")
              ? allowed(JsonCodec.string(args, "path", ""))
              : new File(activity.getCacheDir(), "croc-export-" + UUID.randomUUID());
      if (method.equals("files.exportText"))
        try (FileOutputStream output = new FileOutputStream(exportFile)) {
          output.write(JsonCodec.string(args, "text", "").getBytes(StandardCharsets.UTF_8));
        }
    } else
      intent =
          new Intent(Intent.ACTION_OPEN_DOCUMENT)
              .addCategory(Intent.CATEGORY_OPENABLE)
              .setType(
                  method.equals("files.pickText") ? "*/*" : JsonCodec.string(args, "mime", "*/*"));
    pending = result;
    pendingAction = method;
    activity.startActivityForResult(intent, 701);
  }

  public boolean onResult(int request, int code, Intent data) {
    if (request != 701) return false;
    MethodChannel.Result result = pending;
    pending = null;
    if (result == null) return true;
    if (code != Activity.RESULT_OK || data == null || data.getData() == null) {
      result.success(null);
      return true;
    }
    Uri uri = data.getData();
    String action = pendingAction;
    File selectedExport = exportFile;
    if (action.equals("files.pickFolder")) {
      try {
        int flags = data.getFlags();
        if ((flags & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0
            && (flags & Intent.FLAG_GRANT_WRITE_URI_PERMISSION) != 0)
          activity
              .getContentResolver()
              .takePersistableUriPermission(
                  uri,
                  Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        else if ((flags & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0)
          activity
              .getContentResolver()
              .takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        else
          activity
              .getContentResolver()
              .takePersistableUriPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        result.success(uri.toString());
      } catch (Exception error) {
        result.error("FILES", error.getMessage(), null);
      }
      return true;
    }
    new Thread(
            () -> {
              try {
                Object response;
                if (action.equals("files.export") || action.equals("files.exportText")) {
                  try (InputStream input = new FileInputStream(selectedExport);
                      OutputStream output =
                          activity.getContentResolver().openOutputStream(uri, "w")) {
                    if (output == null) throw new IOException("Cannot open selected destination");
                    input.transferTo(output);
                  }
                  if (action.equals("files.exportText")) selectedExport.delete();
                  response = uri.toString();
                } else if (action.equals("files.pickText")) {
                  try (InputStream input = activity.getContentResolver().openInputStream(uri)) {
                    if (input == null) throw new IOException("Cannot read selected file");
                    byte[] bytes = input.readNBytes(10 * 1024 * 1024 + 1);
                    if (bytes.length > 10 * 1024 * 1024)
                      throw new IOException("Import file is larger than 10 MB");
                    response =
                        JsonCodec.map(
                            "text", new String(bytes, StandardCharsets.UTF_8), "name", name(uri));
                  }
                } else {
                  File destination = new File(root, UUID.randomUUID() + "_" + safeName(name(uri)));
                  try (InputStream input = activity.getContentResolver().openInputStream(uri);
                      OutputStream output = new FileOutputStream(destination)) {
                    if (input == null) throw new IOException("Cannot read selected file");
                    input.transferTo(output);
                  }
                  response =
                      JsonCodec.map(
                          "name",
                          displayName(destination.getName()),
                          "path",
                          destination.getPath(),
                          "size",
                          destination.length(),
                          "mime",
                          mime(destination.getName()));
                }
                activity.runOnUiThread(() -> result.success(response));
              } catch (Exception error) {
                activity.runOnUiThread(() -> result.error("FILES", error.getMessage(), null));
              }
            },
            "croc-files")
        .start();
    return true;
  }

  public String name(Uri uri) {
    try (Cursor cursor =
        activity
            .getContentResolver()
            .query(uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
      if (cursor != null && cursor.moveToFirst()) return cursor.getString(0);
    }
    return "file";
  }

  public static String safeName(String name) {
    String clean = name.replaceAll("[\\\\/\\p{Cntrl}:*?\"<>|]", "_").trim();
    if (clean.isEmpty() || clean.equals(".") || clean.equals(".."))
      throw new IllegalArgumentException("Enter a valid filename");
    return clean.substring(0, Math.min(160, clean.length()));
  }

  private String displayName(String name) {
    return name.matches("^[a-f0-9-]{36}_.*") ? name.substring(37) : name;
  }

  public static String mime(String name) {
    String ext = android.webkit.MimeTypeMap.getFileExtensionFromUrl(name);
    String value =
        android.webkit.MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(ext.toLowerCase(Locale.ROOT));
    return value == null ? "application/octet-stream" : value;
  }

  private List<Map<String, Object>> media(String kind) {
    Uri base =
        kind.equals("audio")
            ? MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            : kind.equals("image")
                ? MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                : MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
    List<Map<String, Object>> result = new ArrayList<>();
    String[] projection = {
      MediaStore.MediaColumns._ID,
      MediaStore.MediaColumns.DISPLAY_NAME,
      MediaStore.MediaColumns.SIZE,
      MediaStore.MediaColumns.MIME_TYPE
    };
    try (Cursor cursor =
        activity
            .getContentResolver()
            .query(base, projection, null, null, MediaStore.MediaColumns.DATE_ADDED + " DESC")) {
      if (cursor != null)
        while (cursor.moveToNext())
          result.add(
              JsonCodec.map(
                  "name",
                  cursor.getString(1),
                  "uri",
                  ContentUris.withAppendedId(base, cursor.getLong(0)).toString(),
                  "size",
                  cursor.getLong(2),
                  "mime",
                  cursor.getString(3)));
    }
    return result;
  }
}
