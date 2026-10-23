package com.example.crocbrowser.downloads;

import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.graphics.BitmapFactory;
import android.net.*;
import android.os.*;
import android.provider.DocumentsContract;
import com.example.crocbrowser.MainActivity;
import com.example.crocbrowser.R;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;
import org.json.JSONObject;

/** Persistent, bounded HTTP transfers. Pause/resume validates Range and object validators. */
public final class DownloadService extends Service {
  public static final String EVENT = "com.example.crocbrowser.DOWNLOADS_CHANGED";
  private DownloadRepository repository;
  private final List<DownloadTask> tasks = new ArrayList<>();
  private final Set<String> running = new HashSet<>();
  private final ExecutorService workers = Executors.newFixedThreadPool(6);
  private final Handler main = new Handler(Looper.getMainLooper());
  private int concurrency = 3;
  private boolean wifiOnly = false, closed = false;
  private long lastNotification;
  private final Runnable tick =
      new Runnable() {
        public void run() {
          if (closed) return;
          synchronized (DownloadService.this) {
            persist();
            pump();
            notifyProgress();
          }
          main.postDelayed(this, 1000);
        }
      };

  @Override
  public void onCreate() {
    super.onCreate();
    repository = new DownloadRepository(this);
    getSystemService(NotificationManager.class)
        .createNotificationChannel(
            new NotificationChannel(
                "croc_downloads", "Crock downloads", NotificationManager.IMPORTANCE_LOW));
    try {
      tasks.addAll(repository.load());
      for (DownloadTask task : tasks) {
        task.speed=0;
        if (task.state.equals("running") || task.state.equals("retrying")) task.state = "queued";
      }
    } catch (Exception error) {
      stopSelf();
      return;
    }
    concurrency = getSharedPreferences("transfer_options", 0).getInt("concurrency", 3);
    wifiOnly = getSharedPreferences("transfer_options", 0).getBoolean("wifiOnly", false);
    startForeground(714, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
    main.post(tick);
  }

  @Override
  public synchronized int onStartCommand(Intent intent, int flags, int startId) {
    if (intent != null)
      try {
        String action = intent.getStringExtra("action"), id = intent.getStringExtra("id");
        if ("enqueue".equals(action)) {
          JSONObject json = new JSONObject(intent.getStringExtra("request"));
          Uri uri = Uri.parse(json.optString("url"));
          boolean magnet = "magnet".equals(uri.getScheme());
          if (!magnet
              && (!"https".equalsIgnoreCase(uri.getScheme())
                      && !"http".equalsIgnoreCase(uri.getScheme())
                  || uri.getHost() == null
                  || uri.getUserInfo() != null))
            throw new IllegalArgumentException(
                "Use an HTTP, HTTPS or magnet download URL without embedded credentials");
          if (magnet
              && (Uri.parse("https://magnet.invalid/" + uri.getEncodedSchemeSpecificPart())
                      .getQueryParameter("xt")
                  == null))
            throw new IllegalArgumentException("Magnet link is missing its torrent hash");
          String name =
              json.optString("name", "download").replaceAll("[\\\\/\\p{Cntrl}:*?\"<>|]", "_");
          if (name.isBlank() || name.equals(".") || name.equals("..")) name = "download";
          json.put("name", name.substring(0, Math.min(160, name.length())))
              .put("id", UUID.randomUUID().toString());
          tasks.add(0, new DownloadTask(json));
        } else if ("settings".equals(action)) {
          concurrency = Math.max(1, Math.min(6, intent.getIntExtra("concurrency", 3)));
          wifiOnly = intent.getBooleanExtra("wifiOnly", false);
          getSharedPreferences("transfer_options", 0)
              .edit()
              .putInt("concurrency", concurrency)
              .putBoolean("wifiOnly", wifiOnly)
              .apply();
        } else {
          for (DownloadTask task : new ArrayList<>(tasks))
            if (task.id.equals(id)) {
              if ("pause".equals(action) || "cancel".equals(action) || "remove".equals(action)) {
                task.stop = true;
                task.state = "pause".equals(action) ? "paused" : "cancelled";
                if (task.connection != null) task.connection.disconnect();
                StreamDownloads.cancel(task.id);
                if (!"pause".equals(action)) task.partial(repository.root).delete();
                if ("remove".equals(action)) {
                  if (task.stream()) StreamDownloads.remove(this, task);
                  deleteManaged(task.completed(repository.root));
                  new File(repository.root, task.id + ".torrent-meta").delete();
                  tasks.remove(task);
                }
              } else if ("resume".equals(action) || "retry".equals(action)) {
                if (!task.state.equals("complete")) {
                  task.stop = running.contains(task.id);
                  task.state = "queued";
                  task.error = "";
                  task.attempts = 0;
                }
              }
            }
        }
      } catch (Exception error) {
        broadcast("Could not update downloads: " + error.getMessage());
      }
    persist();
    pump();
    return START_STICKY;
  }

  private synchronized void pump() {
    if (closed || repository == null) return;
    concurrency =
        Math.max(
            1, Math.min(6, getSharedPreferences("transfer_options", 0).getInt("concurrency", 3)));
    wifiOnly = getSharedPreferences("transfer_options", 0).getBoolean("wifiOnly", false);
    ConnectivityManager cm = getSystemService(ConnectivityManager.class);
    NetworkCapabilities caps = cm.getNetworkCapabilities(cm.getActiveNetwork());
    if (caps == null
        || (wifiOnly && !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)))
      return;
    for (DownloadTask task : tasks)
      if (running.size() < concurrency
          && task.state.equals("queued")
          && !running.contains(task.id)) {
        task.state = "running";
        task.stop = false;
        running.add(task.id);
        workers.execute(() -> transfer(task));
      }
    if (running.isEmpty()
        && tasks.stream().noneMatch(t -> t.state.equals("queued") || t.state.equals("retrying"))) {
      main.removeCallbacks(tick);
      stopForeground(STOP_FOREGROUND_REMOVE);
      stopSelf();
    }
  }

  private void transfer(DownloadTask task) {
    File partial = task.partial(repository.root);
    try {
      if (task.stream()) {
        StreamDownloads.transfer(this, task);
        return;
      }
      if (task.torrent()) {
        TorrentDownloads.transfer(task, repository.root);
        return;
      }
      long offset = partial.exists() ? partial.length() : 0;
      // Without a validator, combining old and new response bodies can corrupt a file.
      if (offset > 0 && task.etag.isEmpty() && task.modified.isEmpty()) {
        offset = 0;
        task.bytes = 0;
      }
      URL target = new URL(task.url);
      String initialOrigin = origin(target);
      HttpURLConnection connection = null;
      for (int redirect = 0; redirect < 8; redirect++) {
        if (task.stop) throw new InterruptedIOException("Paused");
        connection = (HttpURLConnection) target.openConnection();
        task.connection = connection;
        connection.setConnectTimeout(20000);
        connection.setReadTimeout(25000);
        connection.setInstanceFollowRedirects(false);
        connection.setRequestProperty("Accept-Encoding", "identity");
        Iterator<String> keys = task.headers.keys();
        while (keys.hasNext()) {
          String key = keys.next();
          if (key.equalsIgnoreCase("Host") || key.equalsIgnoreCase("Range") || key.contains("\n"))
            continue;
          if ((key.equalsIgnoreCase("Cookie") || key.equalsIgnoreCase("Authorization"))
              && !origin(target).equals(initialOrigin)) continue;
          String value = task.headers.optString(key);
          if (!value.contains("\r") && !value.contains("\n"))
            connection.setRequestProperty(key, value);
        }
        if (offset > 0) {
          connection.setRequestProperty("Range", "bytes=" + offset + "-");
          if (!task.etag.isEmpty() && !task.etag.startsWith("W/"))
            connection.setRequestProperty("If-Range", task.etag);
          else if (!task.modified.isEmpty())
            connection.setRequestProperty("If-Range", task.modified);
        }
        int status = connection.getResponseCode();
        if (status >= 300 && status <= 399 && status != 304) {
          String location = connection.getHeaderField("Location");
          URL next = new URL(target, location);
          if (!next.getProtocol().equals("https") && !next.getProtocol().equals("http"))
            throw new IOException("Unsupported redirect");
          if (target.getProtocol().equals("https") && next.getProtocol().equals("http"))
            throw new IOException("Insecure download redirect blocked");
          connection.disconnect();
          target = next;
          continue;
        }
        if (status == 416) {
          String range = connection.getHeaderField("Content-Range");
          long expected =
              range != null && range.contains("/")
                  ? Long.parseLong(range.substring(range.lastIndexOf('/') + 1))
                  : -1;
          String responseTag = connection.getHeaderField("ETag"),
              responseDate = connection.getHeaderField("Last-Modified");
          boolean same =
              (!task.etag.isEmpty() && !task.etag.startsWith("W/") && task.etag.equals(responseTag))
                  || (!task.modified.isEmpty() && task.modified.equals(responseDate));
          if (offset > 0 && offset == expected && same) {
            task.total = expected;
            finish(task, partial);
            return;
          }
          partial.delete();
          task.bytes = 0;
          task.etag = "";
          task.modified = "";
          throw new IOException("Resume offset rejected; retry to restart");
        }
        if (status != 200 && status != 206) throw new IOException("HTTP " + status);
        if (status == 206) {
          String range = connection.getHeaderField("Content-Range");
          if (range == null || !range.startsWith("bytes " + offset + "-"))
            throw new IOException("Invalid resumed response");
          String total = range.substring(range.lastIndexOf('/') + 1);
          task.total = total.equals("*") ? -1 : Long.parseLong(total);
        } else {
          offset = 0;
          task.total = connection.getContentLengthLong();
        }
        String etag = connection.getHeaderField("ETag"),
            modified = connection.getHeaderField("Last-Modified");
        if (etag != null) task.etag = etag;
        if (modified != null) task.modified = modified;
        String type = connection.getContentType();
        if (type != null) task.mime = type.split(";")[0];
        try (InputStream input = connection.getInputStream();
            RandomAccessFile output = new RandomAccessFile(partial, "rw")) {
          if (offset == 0) output.setLength(0);
          output.seek(offset);
          task.bytes = offset;
          byte[] buffer = new byte[64 * 1024];
          int read;
          long sample = SystemClock.elapsedRealtime(), sampleBytes = task.bytes;
          while ((read = input.read(buffer)) != -1) {
            if (task.stop || closed) throw new InterruptedIOException("Transfer paused");
            output.write(buffer, 0, read);
            task.bytes += read;
            long now = SystemClock.elapsedRealtime();
            if (now - sample >= 500) {
              task.speed = (task.bytes - sampleBytes) * 1000 / (now - sample);
              sample = now;
              sampleBytes = task.bytes;
            }
          }
        }
        if (task.stop) throw new InterruptedIOException("Transfer paused");
        if (task.total >= 0 && task.bytes != task.total)
          throw new IOException("Connection ended before the file was complete");
        finish(task, partial);
        return;
      }
      throw new IOException("Too many redirects");
    } catch (Exception error) {
      synchronized (this) {
        if (!task.stop && !closed && task.state.equals("running")) {
          task.attempts++;
          task.error = error.getMessage() == null ? "Transfer failed" : error.getMessage();
          task.state = task.attempts < 3 ? "retrying" : "failed";
        }
      }
      if (task.state.equals("retrying"))
        main.postDelayed(
            () -> {
              synchronized (DownloadService.this) {
                if (task.state.equals("retrying")) {
                  task.state = "queued";
                  persist();
                  pump();
                }
              }
            },
            Math.min(30000, 2000L * task.attempts));
    } finally {
      if (task.connection != null) {
        task.connection.disconnect();
        task.connection = null;
      }
      synchronized (this) {
        running.remove(task.id);
        task.speed = 0;
        if (task.stop && task.state.equals("cancelled")) {
          partial.delete();
          if (task.stream()) StreamDownloads.remove(this, task);
          if (task.torrent()) deleteManaged(task.completed(repository.root));
        }
        persist();
        pump();
      }
    }
  }

  private void finish(DownloadTask task, File partial) throws Exception {
    if (task.stop) throw new InterruptedIOException("Cancelled");
    File completed = task.completed(repository.root);
    if (!partial.renameTo(completed))
      throw new IOException("Could not finalize the downloaded file");
    task.state = "complete";
    task.bytes = completed.length();
    task.total = task.bytes;
    task.error = "";
    if (!task.tree.isEmpty())
      try {
        Uri tree = Uri.parse(task.tree),
            parent =
                DocumentsContract.buildDocumentUriUsingTree(
                    tree, DocumentsContract.getTreeDocumentId(tree));
        Uri document =
            DocumentsContract.createDocument(getContentResolver(), parent, task.mime, task.name);
        if (document == null) throw new IOException("Folder is unavailable");
        try (InputStream input = new FileInputStream(completed);
            OutputStream output = getContentResolver().openOutputStream(document, "w")) {
          if (output == null) throw new IOException("Cannot write to selected folder");
          input.transferTo(output);
        }
        task.exportUri = document.toString();
      } catch (Exception error) {
        task.error = "Downloaded locally. Folder copy failed: " + error.getMessage();
      }
  }

  private static String origin(URL url) {
    return url.getProtocol() + "://" + url.getHost() + ":" + url.getPort();
  }

  private void deleteManaged(File file) {
    try {
      String root = repository.root.getCanonicalPath() + File.separator;
      if (!file.getCanonicalPath().startsWith(root)) return;
      if (file.isDirectory()) {
        File[] children = file.listFiles();
        if (children != null) for (File child : children) deleteManaged(child);
      }
      file.delete();
    } catch (IOException ignored) {
    }
  }

  private synchronized void persist() {
    if (repository == null) return;
    try {
      repository.save(tasks);
      broadcast("");
    } catch (Exception error) {
      broadcast("Download storage error: " + error.getMessage());
    }
  }

  private void broadcast(String error) {
    sendBroadcast(new Intent(EVENT).setPackage(getPackageName()).putExtra("error", error));
  }

  private Notification notification() {
    long active = tasks.stream().filter(t -> t.state.equals("running")).count();
    long queued =
        tasks.stream().filter(t -> t.state.equals("queued") || t.state.equals("retrying")).count();
    PendingIntent open =
        PendingIntent.getActivity(
            this,
            0,
            new Intent(this, MainActivity.class).putExtra("openDownloads", true),
            PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    Notification.Builder builder =
        new Notification.Builder(this, "croc_downloads")
            .setSmallIcon(R.drawable.ic_notification_crock)
            .setLargeIcon(BitmapFactory.decodeResource(getResources(), R.drawable.crock_logo))
            .setContentTitle("Crock Browser downloads")
            .setContentText(active + " active · " + queued + " queued")
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true);
    return builder.build();
  }

  private void notifyProgress() {
    if (SystemClock.elapsedRealtime() - lastNotification > 900) {
      getSystemService(NotificationManager.class).notify(714, notification());
      lastNotification = SystemClock.elapsedRealtime();
    }
  }

  @Override
  public void onTimeout(int startId, int type) {
    synchronized (this) {
      for (DownloadTask task : tasks)
        if (task.state.equals("running") || task.state.equals("queued")) {
          task.stop = true;
          task.state = "paused";
          task.error = "Android paused long-running transfers. Resume to continue.";
          if (task.connection != null) task.connection.disconnect();
        }
      persist();
    }
    stopForeground(STOP_FOREGROUND_REMOVE);
    stopSelf();
  }

  @Override
  public void onDestroy() {
    closed = true;
    main.removeCallbacks(tick);
    for (DownloadTask task : tasks)
      if (task.state.equals("running")) {
        task.stop = true;
        task.state = "paused";
        if (task.connection != null) task.connection.disconnect();
      }
    persist();
    workers.shutdownNow();
    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent intent) {
    return null;
  }
}
