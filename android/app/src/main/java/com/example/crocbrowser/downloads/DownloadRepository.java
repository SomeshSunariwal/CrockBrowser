package com.example.crocbrowser.downloads;

import android.content.Context;
import com.example.crocbrowser.core.EncryptedStore;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;

/** Transfer headers and URLs are encrypted at rest, alongside persistent queue metadata. */
public final class DownloadRepository {
  private final EncryptedStore encrypted;
  public final File root;

  public DownloadRepository(Context context) {
    encrypted = new EncryptedStore(context);
    root = new File(context.getExternalFilesDir(null), "downloads");
    root.mkdirs();
  }

  public List<DownloadTask> load() throws Exception {
    JSONArray json = new JSONArray(encrypted.read("downloads", "[]"));
    List<DownloadTask> tasks = new ArrayList<>();
    for (int i = 0; i < json.length(); i++) tasks.add(new DownloadTask(json.getJSONObject(i)));
    return tasks;
  }

  public synchronized void save(List<DownloadTask> tasks) throws Exception {
    JSONArray json = new JSONArray();
    for (DownloadTask task : tasks) json.put(task.json());
    encrypted.write("downloads", json.toString());
  }

  public List<Map<String, Object>> snapshot() throws Exception {
    List<Map<String, Object>> rows = new ArrayList<>();
    for (DownloadTask task : load()) rows.add(task.publicMap());
    return rows;
  }
}
