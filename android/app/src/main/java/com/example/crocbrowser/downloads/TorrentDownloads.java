package com.example.crocbrowser.downloads;

import com.frostwire.jlibtorrent.*;
import java.io.*;
import java.net.*;

/** Independent torrent sessions avoid duplicate-infohash collisions between download rows. */
public final class TorrentDownloads {
  public static boolean supports(String url) {
    return url.startsWith("magnet:")
        || url.toLowerCase(java.util.Locale.ROOT).split("\\?", 2)[0].endsWith(".torrent");
  }

  public static void transfer(DownloadTask task, File root) throws Exception {
    File directory = task.completed(root);
    directory.mkdirs();
    File metadata = new File(root, task.id + ".torrent-meta");
    SessionManager session = new SessionManager();
    try {
      session.start();
      if (!metadata.exists()) {
        byte[] data;
        if (task.url.startsWith("magnet:")) {
          data = session.fetchMagnet(task.url, 30, directory);
          if (data == null)
            throw new IOException("No torrent metadata received. Check that peers are available.");
        } else {
          HttpURLConnection connection = (HttpURLConnection) new URL(task.url).openConnection();
          task.connection = connection;
          connection.setConnectTimeout(20000);
          connection.setReadTimeout(25000);
          try (InputStream input = connection.getInputStream();
              ByteArrayOutputStream buffer = new ByteArrayOutputStream()) {
            byte[] chunk = new byte[8192];
            int count;
            while ((count = input.read(chunk)) != -1) {
              if (task.stop) throw new InterruptedIOException("Paused");
              if (buffer.size() + count > 16 * 1024 * 1024)
                throw new IOException("Torrent metadata is too large");
              buffer.write(chunk, 0, count);
            }
            data = buffer.toByteArray();
          } finally {
            connection.disconnect();
            task.connection = null;
          }
        }
        try (FileOutputStream output = new FileOutputStream(metadata)) {
          output.write(data);
        }
      }
      if (task.stop) throw new InterruptedIOException("Paused");
      TorrentInfo info = new TorrentInfo(metadata);
      session.download(info, directory);
      long waitUntil = System.currentTimeMillis() + 30000;
      TorrentHandle handle;
      while ((handle = session.find(info)) == null || !handle.isValid()) {
        if (task.stop) throw new InterruptedIOException("Paused");
        if (System.currentTimeMillis() > waitUntil)
          throw new IOException("Torrent could not be started");
        Thread.sleep(200);
      }
      while (!task.stop) {
        TorrentStatus status = handle.status();
        task.bytes = status.totalDone();
        task.total = status.totalWanted();
        task.speed = status.downloadRate();
        if (status.errorCode().value() != 0) throw new IOException(status.errorCode().message());
        if (status.isFinished() || status.isSeeding()) {
          handle.pause();
          task.state = "complete";
          task.error =
              task.tree.isEmpty()
                  ? ""
                  : "Torrent saved in Crock files. Export individual files from the Files screen.";
          return;
        }
        Thread.sleep(700);
      }
      handle.pause();
      throw new InterruptedIOException("Paused");
    } finally {
      session.stop();
    }
  }
}
