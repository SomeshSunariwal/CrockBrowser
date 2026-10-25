package com.browser.crockbrowser.downloads;

import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.SystemClock;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;
import org.schabi.newpipe.extractor.stream.Stream;

/** Resumable component transfers and MP4 muxing using Android APIs, without FFmpeg. */
final class YouTubeDownloads {
  private YouTubeDownloads() {}

  private static File component(DownloadTask task, File root, String part) {
    return new File(root, task.id + ".youtube-" + part + ".part");
  }

  static void transfer(DownloadTask task, File root, File output) throws Exception {
    check(task);
    task.phase = "Finding video streams";
    YouTubeExtractor.Selection choice = YouTubeExtractor.resolve(task.url, task.youtubeFormat);
    check(task);
    File primary = component(task, root, "video"), audio = component(task, root, "audio");
    long[] sizes = {YouTubeExtractor.length(choice.primary), YouTubeExtractor.length(choice.audio)};
    task.bytes = primary.length() + (choice.audio == null ? 0 : audio.length());
    task.phase = "";
    download(task, choice.primary, primary, 0, sizes, primary, choice.audio == null ? null : audio);
    if (choice.audio == null) {
      check(task);
      if (output.exists() && !output.delete())
        throw new IOException("Could not replace partial output");
      if (!primary.renameTo(output)) throw new IOException("Could not prepare downloaded file");
    } else {
      download(task, choice.audio, audio, 1, sizes, primary, audio);
      check(task);
      task.phase = "Combining audio and video";
      task.speed = 0;
      mux(task, primary, audio, output);
    }
    check(task);
  }

  private static void check(DownloadTask task) throws InterruptedIOException {
    if (task.stop || Thread.currentThread().isInterrupted())
      throw new InterruptedIOException("Download paused");
  }

  private static void update(DownloadTask task, long[] sizes, File primary, File audio) {
    task.bytes = primary.length() + (audio == null ? 0 : audio.length());
    task.total =
        sizes[0] > 0 && (audio == null || sizes[1] > 0)
            ? sizes[0] + (audio == null ? 0 : sizes[1])
            : -1;
  }

  private static String value(URL url, String key) {
    if (url.getQuery() != null)
      for (String pair : url.getQuery().split("&")) {
        String[] parts = pair.split("=", 2);
        if (parts.length == 2 && parts[0].equals(key)) return parts[1];
      }
    return "";
  }

  private static URL mediaUrl(String input) throws Exception {
    URL url = new URL(input);
    String host = url.getHost().toLowerCase(java.util.Locale.ROOT);
    if (!url.getProtocol().equals("https")
        || url.getUserInfo() != null
        || (!host.equals("googlevideo.com")
            && !host.endsWith(".googlevideo.com")
            && !host.equals("youtube.com")
            && !host.endsWith(".youtube.com"))) throw new IOException("Untrusted video stream URL");
    return url;
  }

  private static void download(
      DownloadTask task,
      Stream stream,
      File file,
      int index,
      long[] sizes,
      File primary,
      File audio)
      throws Exception {
    check(task);
    URL url = mediaUrl(stream.getContent());
    File metadata = new File(file.getPath() + ".meta");
    JSONObject saved = new JSONObject();
    if (metadata.isFile() && metadata.length() < 8192) {
      try (InputStream input = new FileInputStream(metadata)) {
        saved = new JSONObject(new String(input.readAllBytes(), StandardCharsets.UTF_8));
      } catch (Exception ignored) {
        /* A damaged checkpoint requires a clean component. */
      }
    }
    String fingerprint =
        stream.getId() + ":" + value(url, "lmt") + ":" + YouTubeExtractor.length(stream);
    boolean validator =
        !value(url, "lmt").isEmpty()
            || !saved.optString("etag").isEmpty()
            || !saved.optString("modified").isEmpty();
    long offset = file.length();
    if (!fingerprint.equals(saved.optString("fingerprint")) || !validator) {
      if (file.exists() && !file.delete()) throw new IOException("Could not restart component");
      offset = 0;
    }
    if (offset > 0 && offset == saved.optLong("total", -1)) {
      sizes[index] = offset;
      update(task, sizes, primary, audio);
      return;
    }
    HttpURLConnection connection = null;
    try {
      for (int redirects = 0; redirects < 8; redirects++) {
        check(task);
        connection = (HttpURLConnection) url.openConnection();
        task.connection = connection;
        connection.setConnectTimeout(20000);
        connection.setReadTimeout(25000);
        connection.setInstanceFollowRedirects(false);
        connection.setRequestProperty("Accept-Encoding", "identity");
        if (offset > 0) {
          connection.setRequestProperty("Range", "bytes=" + offset + "-");
          String etag = saved.optString("etag"), modified = saved.optString("modified");
          if (!etag.isEmpty() && !etag.startsWith("W/"))
            connection.setRequestProperty("If-Range", etag);
          else if (!modified.isEmpty()) connection.setRequestProperty("If-Range", modified);
        }
        int status = connection.getResponseCode();
        if (status >= 300 && status < 400) {
          String location = connection.getHeaderField("Location");
          if (location == null) throw new IOException("Invalid stream redirect");
          URL next = mediaUrl(new URL(url, location).toString());
          connection.disconnect();
          url = next;
          continue;
        }
        if (status == 401 || status == 403 || status == 410) {
          YouTubeExtractor.invalidate(task.url);
          throw new IOException(
              "YouTube rejected the video stream (HTTP " + status + "). Try again.");
        }
        if (status != 200 && status != 206)
          throw new IOException("Video stream returned HTTP " + status);
        long expected;
        if (status == 206) {
          String range = connection.getHeaderField("Content-Range");
          if (range == null || !range.startsWith("bytes " + offset + "-"))
            throw new IOException("Invalid resumed video response");
          String total = range.substring(range.lastIndexOf('/') + 1);
          expected = total.equals("*") ? -1 : Long.parseLong(total);
        } else {
          offset = 0;
          expected = connection.getContentLengthLong();
        }
        sizes[index] = expected;
        JSONObject checkpoint =
            new JSONObject()
                .put("fingerprint", fingerprint)
                .put("total", expected)
                .put(
                    "etag",
                    connection.getHeaderField("ETag") == null
                        ? ""
                        : connection.getHeaderField("ETag"))
                .put(
                    "modified",
                    connection.getHeaderField("Last-Modified") == null
                        ? ""
                        : connection.getHeaderField("Last-Modified"));
        try (OutputStream meta = new FileOutputStream(metadata)) {
          meta.write(checkpoint.toString().getBytes(StandardCharsets.UTF_8));
        }
        try (InputStream input = connection.getInputStream();
            RandomAccessFile output = new RandomAccessFile(file, "rw")) {
          if (offset == 0) output.setLength(0);
          output.seek(offset);
          update(task, sizes, primary, audio);
          long sample = SystemClock.elapsedRealtime(), sampleBytes = task.bytes;
          byte[] buffer = new byte[65536];
          int count;
          while ((count = input.read(buffer)) != -1) {
            check(task);
            output.write(buffer, 0, count);
            update(task, sizes, primary, audio);
            long now = SystemClock.elapsedRealtime();
            if (now - sample >= 100) {
              task.speed = Math.max(0, task.bytes - sampleBytes) * 1000 / (now - sample);
              sample = now;
              sampleBytes = task.bytes;
            }
          }
        }
        check(task);
        if (expected >= 0 && file.length() != expected)
          throw new IOException("Video connection ended before completion");
        return;
      }
      throw new IOException("Too many video redirects");
    } finally {
      if (connection != null) connection.disconnect();
      task.connection = null;
    }
  }

  private static int track(MediaExtractor extractor, String prefix) throws IOException {
    for (int i = 0; i < extractor.getTrackCount(); i++) {
      String mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME);
      if (mime != null && mime.startsWith(prefix)) {
        extractor.selectTrack(i);
        return i;
      }
    }
    throw new IOException("The downloaded stream is missing its " + prefix + " track");
  }

  private static void mux(DownloadTask task, File video, File audio, File output) throws Exception {
    MediaExtractor v = new MediaExtractor(), a = new MediaExtractor();
    MediaMuxer muxer = null;
    boolean complete = false;
    try {
      v.setDataSource(video.getPath());
      a.setDataSource(audio.getPath());
      int videoTrack = track(v, "video/"), audioTrack = track(a, "audio/");
      muxer = new MediaMuxer(output.getPath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
      int outVideo = muxer.addTrack(v.getTrackFormat(videoTrack)),
          outAudio = muxer.addTrack(a.getTrackFormat(audioTrack));
      muxer.start();
      copy(task, v, v.getTrackFormat(videoTrack), muxer, outVideo);
      copy(task, a, a.getTrackFormat(audioTrack), muxer, outAudio);
      check(task);
      muxer.stop();
      complete = true;
    } finally {
      v.release();
      a.release();
      if (muxer != null) muxer.release();
      if (!complete) output.delete();
    }
  }

  private static void copy(
      DownloadTask task, MediaExtractor source, MediaFormat format, MediaMuxer output, int track)
      throws Exception {
    int size =
        format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)
            ? format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
            : 1048576;
    if (size > 16 * 1048576) throw new IOException("Video sample is too large");
    ByteBuffer buffer = ByteBuffer.allocateDirect(Math.max(1048576, size));
    MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    while (true) {
      check(task);
      buffer.clear();
      int count = source.readSampleData(buffer, 0);
      if (count < 0) return;
      if ((source.getSampleFlags() & MediaExtractor.SAMPLE_FLAG_ENCRYPTED) != 0)
        throw new IOException("Encrypted streams are not supported");
      info.set(
          0,
          count,
          source.getSampleTime(),
          (source.getSampleFlags() & MediaExtractor.SAMPLE_FLAG_SYNC) != 0
              ? MediaCodec.BUFFER_FLAG_KEY_FRAME
              : 0);
      output.writeSampleData(track, buffer, info);
      source.advance();
    }
  }

  static void cleanup(DownloadTask task, File root) {
    for (String part : new String[] {"video", "audio"}) {
      File file = component(task, root, part);
      file.delete();
      new File(file.getPath() + ".meta").delete();
    }
  }
}
