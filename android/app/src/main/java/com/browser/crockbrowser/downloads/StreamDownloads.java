package com.browser.crockbrowser.downloads;

import android.content.Context;
import android.net.Uri;
import androidx.media3.database.StandaloneDatabaseProvider;
import androidx.media3.datasource.cache.CacheDataSource;
import androidx.media3.datasource.cache.NoOpCacheEvictor;
import androidx.media3.datasource.cache.SimpleCache;
import androidx.media3.exoplayer.offline.DefaultDownloaderFactory;
import androidx.media3.exoplayer.offline.DownloadRequest;
import androidx.media3.exoplayer.offline.Downloader;
import java.io.File;
import java.io.InterruptedIOException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;

/** HLS/DASH on-demand downloads. Segment caches resume and remain playable offline. */
@androidx.annotation.OptIn(markerClass = androidx.media3.common.util.UnstableApi.class)
public final class StreamDownloads {
  private static final Map<String, SimpleCache> caches = new HashMap<>();
  private static final Map<String, Downloader> active = new HashMap<>();

  public static boolean supports(String url, String mime) {
    String path = Uri.parse(url).getPath();
    return (path != null && (path.endsWith(".m3u8") || path.endsWith(".mpd")))
        || mime.contains("mpegurl")
        || mime.contains("dash+xml");
  }

  public static synchronized SimpleCache cache(Context context, String id) {
    if (!id.matches("[a-zA-Z0-9-]+"))
      throw new IllegalArgumentException("Invalid media identifier");
    return caches.computeIfAbsent(
        id,
        key ->
            new SimpleCache(
                new File(context.getFilesDir(), "media-cache/" + key),
                new NoOpCacheEvictor(),
                new StandaloneDatabaseProvider(context)));
  }

  public static CacheDataSource.Factory source(
      Context context, DownloadTask task, boolean offline) {
    CacheDataSource.Factory factory =
        new CacheDataSource.Factory().setCache(cache(context, task.id));
    if (!offline) {
      factory.setUpstreamDataSourceFactory(
          com.browser.crockbrowser.media.MediaNetwork.factory(context, task.url, task.headers));
    } else factory.setUpstreamDataSourceFactory(null);
    return factory;
  }

  public static void transfer(Context context, DownloadTask task) throws Exception {
    DownloadRequest request =
        new DownloadRequest.Builder(task.id, Uri.parse(task.url))
            .setMimeType(
                task.mime.contains("dash+xml") || task.url.toLowerCase(Locale.ROOT).contains(".mpd")
                    ? "application/dash+xml"
                    : "application/x-mpegURL")
            .build();
    Downloader downloader =
        new DefaultDownloaderFactory(source(context, task, false), Runnable::run)
            .createDownloader(request);
    synchronized (StreamDownloads.class) {
      active.put(task.id, downloader);
    }
    long[] sample = {android.os.SystemClock.elapsedRealtime(), task.bytes};
    try {
      if (task.stop) throw new InterruptedIOException("Paused");
      downloader.download(
          (length, bytes, percent) -> {
            task.total = length;
            task.bytes = bytes;
            long now = android.os.SystemClock.elapsedRealtime();
            if (now - sample[0] >= 500) {
              task.speed = Math.max(0, bytes - sample[1]) * 1000 / (now - sample[0]);
              sample[0] = now;
              sample[1] = bytes;
            }
            if (task.stop) downloader.cancel();
          });
      if (task.stop) throw new InterruptedIOException("Paused");
      task.state = "complete";
      task.error =
          task.tree.isEmpty()
              ? ""
              : "Saved for offline playback inside Crock Player; adaptive segments are not exported"
                  + " as a single file.";
    } finally {
      synchronized (StreamDownloads.class) {
        active.remove(task.id);
      }
    }
  }

  public static synchronized void cancel(String id) {
    Downloader downloader = active.get(id);
    if (downloader != null) downloader.cancel();
  }

  public static synchronized void remove(Context context, DownloadTask task) {
    if (active.containsKey(task.id)) return;
    SimpleCache cache = cache(context, task.id);
    for (String key : new HashSet<>(cache.getKeys()))
      try {
        cache.removeResource(key);
      } catch (Exception ignored) {
      }
  }
}
