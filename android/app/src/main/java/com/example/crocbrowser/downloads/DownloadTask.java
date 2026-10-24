package com.example.crocbrowser.downloads;

import com.example.crocbrowser.core.JsonCodec;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

public final class DownloadTask {
  public volatile String id,
      url,
      name,
      mime = "application/octet-stream",
      state = "queued",
      error = "",
      etag = "",
      modified = "",
      tree = "",
      exportUri = "";
  public JSONObject headers = new JSONObject();
  public volatile long bytes = 0, total = -1, created = System.currentTimeMillis(), speed = 0;
  public int attempts = 0;
  public volatile boolean stop = false;
  public transient volatile java.net.HttpURLConnection connection;
  private final List<List<Double>> speedHistory = new ArrayList<>();

  public DownloadTask(JSONObject json) {
    id = json.optString("id");
    url = json.optString("url");
    name = json.optString("name", "download");
    mime = json.optString("mime", mime);
    state = json.optString("state", state);
    error = json.optString("error");
    etag = json.optString("etag");
    modified = json.optString("modified");
    tree = json.optString("tree");
    exportUri = json.optString("exportUri");
    headers =
        json.optJSONObject("headers") == null ? new JSONObject() : json.optJSONObject("headers");
    bytes = json.optLong("bytes");
    speed = json.optLong("speed");
    total = json.optLong("total", -1);
    created = json.optLong("created", created);
    attempts = json.optInt("attempts");
    JSONArray history = json.optJSONArray("speedHistory");
    if (history != null)
      for (int i = 0; i < history.length(); i++) {
        JSONArray sample = history.optJSONArray(i);
        if (sample != null && sample.length() == 2)
          speedHistory.add(ArraysAsSample(sample.optDouble(0), sample.optDouble(1)));
      }
  }

  private static List<Double> ArraysAsSample(double progress, double rate) {
    return java.util.Arrays.asList(progress, rate);
  }

  public synchronized List<List<Double>> graphHistory() {
    if (total > 0) {
      double progress = Math.max(0, Math.min(1, (double) bytes / total));
      if (!speedHistory.isEmpty() && progress < speedHistory.get(speedHistory.size() - 1).get(0))
        speedHistory.clear();
      double rate = Math.max(0, speed);
      if (!state.equals("running") && !speedHistory.isEmpty())
        rate = speedHistory.get(speedHistory.size() - 1).get(1);
      if (speedHistory.isEmpty()) speedHistory.add(ArraysAsSample(0, rate));
      if (progress > 0) {
        List<Double> point = ArraysAsSample(progress, rate);
        int count = speedHistory.size();
        if (count > 1 && progress - speedHistory.get(count - 2).get(0) < .005)
          speedHistory.set(count - 1, point);
        else speedHistory.add(point);
      }
    }
    List<List<Double>> copy = new ArrayList<>();
    for (List<Double> point : speedHistory) copy.add(new ArrayList<>(point));
    return copy;
  }

  public JSONObject json() {
    return new JSONObject(
        JsonCodec.map(
            "id",
            id,
            "url",
            url,
            "name",
            name,
            "mime",
            mime,
            "state",
            state,
            "error",
            error,
            "etag",
            etag,
            "modified",
            modified,
            "tree",
            tree,
            "exportUri",
            exportUri,
            "headers",
            headers,
            "bytes",
            bytes,
            "speed",
            speed,
            "total",
            total,
            "created",
            created,
            "attempts",
            attempts,
            "speedHistory",
            graphHistory()));
  }

  public Map<String, Object> publicMap() {
    return JsonCodec.map(
        "id",
        id,
        "url",
        url,
        "name",
        name,
        "mime",
        mime,
        "state",
        state,
        "error",
        error,
        "bytes",
        bytes,
        "total",
        total,
        "speed",
        speed,
        "created",
        created,
        "exported",
        !exportUri.isEmpty(),
        "stream",
        stream(),
        "torrent",
        torrent(),
        "speedHistory",
        graphHistory());
  }

  public File partial(File root) {
    return new File(root, id + ".part");
  }

  public boolean stream() {
    return StreamDownloads.supports(url, mime);
  }

  public boolean torrent() {
    return TorrentDownloads.supports(url);
  }

  public File completed(File root) {
    File expected = new File(root, id + "_" + name);
    if (expected.exists()) return expected;
    File[] matches = root.listFiles((directory, filename) -> filename.startsWith(id + "_"));
    return matches != null && matches.length == 1 ? matches[0] : expected;
  }
}
