package com.browser.crockbrowser.downloads;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.schabi.newpipe.extractor.MediaFormat;
import org.schabi.newpipe.extractor.NewPipe;
import org.schabi.newpipe.extractor.ServiceList;
import org.schabi.newpipe.extractor.downloader.Downloader;
import org.schabi.newpipe.extractor.downloader.Request;
import org.schabi.newpipe.extractor.downloader.Response;
import org.schabi.newpipe.extractor.stream.AudioStream;
import org.schabi.newpipe.extractor.stream.DeliveryMethod;
import org.schabi.newpipe.extractor.stream.Stream;
import org.schabi.newpipe.extractor.stream.StreamInfo;
import org.schabi.newpipe.extractor.stream.StreamType;
import org.schabi.newpipe.extractor.stream.VideoStream;

/** Local public-video extraction. Browser cookies and credentials are never exported. */
public final class YouTubeExtractor {
  private static boolean initialized;
  private record Cached(StreamInfo info, long at) {}
  private static final Map<String, Cached> cache = new LinkedHashMap<>(4, .75f, true);
  private static final ThreadLocal<Long> deadline = new ThreadLocal<>();

  private YouTubeExtractor() {}

  static synchronized void invalidate(String url) {
    cache.remove(url);
  }

  public static String canonicalUrl(String input) {
    try {
      URI uri = new URI(input);
      String host = uri.getHost();
      if (!"https".equalsIgnoreCase(uri.getScheme())
          || host == null
          || uri.getUserInfo() != null
          || (uri.getPort() != -1 && uri.getPort() != 443)) throw new IllegalArgumentException();
      host = host.toLowerCase(Locale.ROOT);
      String id = null;
      if (host.equals("youtu.be")) id = uri.getPath().substring(1).split("/")[0];
      else if (Set.of("youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com")
          .contains(host)) {
        if ("/watch".equals(uri.getPath()) && uri.getRawQuery() != null) {
          for (String pair : uri.getRawQuery().split("&")) {
            String[] parts = pair.split("=", 2);
            if (parts.length == 2 && parts[0].equals("v"))
              id = URLDecoder.decode(parts[1], StandardCharsets.UTF_8);
          }
        } else if (uri.getPath().matches("/(shorts|embed)/[^/]+/?"))
          id = uri.getPath().split("/")[2];
      }
      if (id == null || !id.matches("[A-Za-z0-9_-]{11}")) throw new IllegalArgumentException();
      return "https://www.youtube.com/watch?v=" + id;
    } catch (Exception error) {
      throw new IllegalArgumentException("Open a YouTube video before downloading");
    }
  }

  private static synchronized StreamInfo info(String input) throws Exception {
    String url = canonicalUrl(input);
    long now = System.nanoTime();
    Cached cached = cache.get(url);
    if (cached != null && now - cached.at() < 90_000_000_000L) return cached.info();
    if (!initialized) {
      NewPipe.init(new Network());
      initialized = true;
    }
    deadline.set(System.nanoTime() + 25_000_000_000L);
    try {
      StreamInfo info = StreamInfo.getInfo(ServiceList.YouTube, url);
      if (info.getStreamType() != StreamType.VIDEO_STREAM)
        throw new IOException("Downloads currently support regular videos, not live streams");
      cache.put(url, new Cached(info, System.nanoTime()));
      while (cache.size() > 4) cache.remove(cache.keySet().iterator().next());
      return info;
    } finally {
      deadline.remove();
    }
  }

  private static int remainingTimeout() throws java.net.SocketTimeoutException {
    Long limit = deadline.get();
    long remaining = limit == null ? 12000 : (limit - System.nanoTime()) / 1_000_000;
    if (Thread.currentThread().isInterrupted() || remaining <= 0)
      throw new java.net.SocketTimeoutException("YouTube qualities request timed out");
    return (int) Math.max(1, Math.min(12000, remaining));
  }

  private static boolean direct(Stream stream) {
    return stream.isUrl()
        && stream.getDeliveryMethod() == DeliveryMethod.PROGRESSIVE_HTTP
        && stream.getContent().startsWith("https://");
  }

  private static AudioStream audio(StreamInfo info) {
    return info.getAudioStreams().stream()
        .filter(s -> direct(s) && s.getFormat() == MediaFormat.M4A)
        .max(
            Comparator.comparingInt(
                    (AudioStream s) ->
                        s.getAudioTrackType() != null
                                && "ORIGINAL".equals(s.getAudioTrackType().name())
                            ? 1
                            : 0)
                .thenComparingInt(AudioStream::getAverageBitrate))
        .orElse(null);
  }

  private static List<VideoStream> videos(StreamInfo info) {
    List<VideoStream> result = new ArrayList<>(info.getVideoStreams());
    result.addAll(info.getVideoOnlyStreams());
    result.removeIf(
        s ->
            !direct(s)
                || s.getFormat() != MediaFormat.MPEG_4
                || (s.getCodec() != null
                    && !s.getCodec().isEmpty()
                    && !s.getCodec().startsWith("avc")
                    && !s.getCodec().startsWith("h264")));
    result.sort(
        Comparator.comparingInt(YouTubeExtractor::height)
            .thenComparingInt(VideoStream::getFps)
            .reversed());
    return result;
  }

  private static int height(VideoStream stream) {
    try {
      return Integer.parseInt(stream.getResolution().split("[^0-9]", 2)[0]);
    } catch (Exception error) {
      return 0;
    }
  }

  static long length(Stream stream) {
    return stream != null && stream.getItagItem() != null
        ? stream.getItagItem().getContentLength()
        : -1;
  }

  public static Map<String, Object> formats(String url) throws Exception {
    StreamInfo info = info(url);
    AudioStream audio = audio(info);
    List<Map<String, Object>> formats = new ArrayList<>();
    Set<String> seen = new HashSet<>();
    for (VideoStream stream : videos(info)) {
      if (stream.isVideoOnly() && audio == null) continue;
      String label = stream.getResolution();
      if (label.isBlank() || !seen.add(label)) continue;
      long total = length(stream);
      if (stream.isVideoOnly()) total = total > 0 && length(audio) > 0 ? total + length(audio) : -1;
      formats.add(
          Map.of(
              "id",
              "video:" + stream.getItag(),
              "label",
              label,
              "mime",
              "video/mp4",
              "extension",
              "mp4",
              "total",
              total,
              "mergesAudio",
              stream.isVideoOnly()));
    }
    if (audio != null)
      formats.add(
          Map.of(
              "id",
              "audio:" + audio.getItag(),
              "label",
              "Audio only",
              "mime",
              "audio/mp4",
              "extension",
              "m4a",
              "total",
              length(audio),
              "mergesAudio",
              false));
    if (formats.isEmpty())
      throw new IOException("No compatible MP4 downloads were found for this video");
    String thumbnail = info.getThumbnails().isEmpty() ? "" : info.getThumbnails().get(0).getUrl();
    return Map.of(
        "title",
        info.getName(),
        "url",
        canonicalUrl(url),
        "thumbnail",
        thumbnail,
        "formats",
        formats);
  }

  static Selection resolve(String url, String format) throws Exception {
    StreamInfo info = info(url);
    AudioStream audio = audio(info);
    if (audio != null && format.equals("audio:" + audio.getItag()))
      return new Selection(audio, null);
    for (VideoStream video : videos(info)) {
      if (format.equals("video:" + video.getItag()) && (!video.isVideoOnly() || audio != null))
        return new Selection(video, video.isVideoOnly() ? audio : null);
    }
    throw new IOException("This quality is no longer available. Choose a quality again.");
  }

  static final class Selection {
    final Stream primary;
    final AudioStream audio;

    Selection(Stream primary, AudioStream audio) {
      this.primary = primary;
      this.audio = audio;
    }
  }

  private static final class Network extends Downloader {
    @Override
    public Response execute(Request request) throws IOException {
      URL url = new URL(request.url());
      if (!url.getProtocol().equals("https"))
        throw new IOException("Insecure extractor request blocked");
      HttpURLConnection connection = (HttpURLConnection) url.openConnection();
      connection.setConnectTimeout(remainingTimeout());
      connection.setReadTimeout(remainingTimeout());
      connection.setRequestMethod(request.httpMethod());
      connection.setRequestProperty(
          "User-Agent",
          "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36");
      for (Map.Entry<String, List<String>> header : request.headers().entrySet()) {
        if (header.getKey().contains("\r") || header.getKey().contains("\n")) continue;
        for (String value : header.getValue()) {
          if (!value.contains("\r") && !value.contains("\n"))
            connection.addRequestProperty(header.getKey(), value);
        }
      }
      try {
        byte[] body = request.dataToSend();
        if (body != null && body.length > 0) {
          connection.setDoOutput(true);
          try (OutputStream output = connection.getOutputStream()) {
            output.write(body);
          }
        }
        int code = connection.getResponseCode();
        if (code == 429)
          throw new IOException("YouTube is rate-limiting requests. Try again later.");
        InputStream input = code >= 400 ? connection.getErrorStream() : connection.getInputStream();
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        if (input != null)
          try (input) {
            byte[] buffer = new byte[16384];
            int count;
            while ((count = input.read(buffer)) != -1) {
              connection.setReadTimeout(remainingTimeout());
              if (bytes.size() + count > 16 * 1024 * 1024)
                throw new IOException("Extractor response is too large");
              bytes.write(buffer, 0, count);
            }
          }
        return new Response(
            code,
            connection.getResponseMessage(),
            connection.getHeaderFields(),
            bytes.toString(StandardCharsets.UTF_8),
            connection.getURL().toString());
      } finally {
        connection.disconnect();
      }
    }
  }
}
