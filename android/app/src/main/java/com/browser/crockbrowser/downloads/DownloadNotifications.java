package com.browser.crockbrowser.downloads;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PointF;
import android.graphics.Shader;
import android.widget.RemoteViews;
import com.browser.crockbrowser.MainActivity;
import com.browser.crockbrowser.R;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/** System notification cards share the service's persisted graph, independent of Flutter. */
final class DownloadNotifications {
  static final int SUMMARY_ID = 714;
  private static final int CARD_ID = 715;
  private static final String CHANNEL = "croc_downloads";
  private static final String GROUP = "com.browser.crockbrowser.DOWNLOADS";
  private static final String TAG_PREFIX = "crock-download:";
  private final Context context;
  private final NotificationManager manager;
  private final PendingIntent open;
  private final Map<String, String> published = new HashMap<>();
  private String lastSummary = "";

  DownloadNotifications(Context context) {
    this.context = context;
    manager = context.getSystemService(NotificationManager.class);
    manager.createNotificationChannel(
        new NotificationChannel(CHANNEL, "Crock downloads", NotificationManager.IMPORTANCE_LOW));
    open =
        PendingIntent.getActivity(
            context,
            714,
            new Intent(context, MainActivity.class)
                .putExtra("openDownloads", true)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    for (android.service.notification.StatusBarNotification notification :
        manager.getActiveNotifications()) {
      String tag = notification.getTag();
      if (tag != null && tag.startsWith(TAG_PREFIX))
        published.put(tag.substring(TAG_PREFIX.length()), "");
    }
  }

  private static boolean active(DownloadTask task) {
    return task.state.equals("running")
        || task.state.equals("queued")
        || task.state.equals("retrying");
  }

  private List<DownloadTask> visible(List<DownloadTask> tasks) {
    List<DownloadTask> rows = new ArrayList<>();
    for (DownloadTask task : tasks)
      if (active(task) || task.state.equals("paused") || published.containsKey(task.id))
        rows.add(task);
    return rows;
  }

  Notification summary(List<DownloadTask> tasks, boolean foreground) {
    List<DownloadTask> rows = visible(tasks);
    Notification.Builder builder;
    if (rows.size() == 1) {
      builder = card(rows.get(0));
    } else {
      long active = rows.stream().filter(DownloadNotifications::active).count();
      Notification.InboxStyle style = new Notification.InboxStyle();
      for (DownloadTask task : rows) style.addLine(task.name + " · " + percentage(task));
      builder =
          base()
              .setContentTitle("Crock Browser downloads")
              .setContentText(active + " active · " + rows.size() + " downloads")
              .setStyle(style);
    }
    return builder.setGroupSummary(true).setOngoing(foreground).build();
  }

  void update(List<DownloadTask> tasks, boolean foreground) {
    Set<String> ids = new HashSet<>();
    for (DownloadTask task : tasks) ids.add(task.id);
    // Also clean up cards from a previous service instance when their task was removed.
    for (android.service.notification.StatusBarNotification notification :
        manager.getActiveNotifications()) {
      String tag = notification.getTag();
      if (tag != null
          && tag.startsWith(TAG_PREFIX)
          && !ids.contains(tag.substring(TAG_PREFIX.length()))) manager.cancel(tag, CARD_ID);
    }
    published.keySet().retainAll(ids);
    List<DownloadTask> rows = visible(tasks);
    StringBuilder summaryKey = new StringBuilder().append(foreground);
    for (DownloadTask task : rows) {
      String fingerprint = task.json().toString();
      if (!fingerprint.equals(published.get(task.id))) {
        manager.notify(TAG_PREFIX + task.id, CARD_ID, card(task).build());
        published.put(task.id, fingerprint);
      }
      summaryKey.append(task.id).append(task.state).append(percentage(task));
      if (rows.size() == 1) summaryKey.append(fingerprint);
    }
    if (rows.isEmpty() && !foreground) {
      manager.cancel(SUMMARY_ID);
      lastSummary = "";
    } else if (!lastSummary.equals(summaryKey.toString())) {
      manager.notify(SUMMARY_ID, summary(tasks, foreground));
      lastSummary = summaryKey.toString();
    }
  }

  private Notification.Builder base() {
    return new Notification.Builder(context, CHANNEL)
        .setSmallIcon(R.drawable.ic_notification_crock)
        .setContentIntent(open)
        .setGroup(GROUP)
        .setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
        .setOnlyAlertOnce(true)
        .setShowWhen(false)
        .setCategory(Notification.CATEGORY_PROGRESS)
        .setVisibility(Notification.VISIBILITY_PRIVATE);
  }

  private Notification.Builder card(DownloadTask task) {
    int color = color(task.state);
    Bitmap graph = graph(task, color);
    return base()
        .setContentTitle(task.name)
        .setContentText(percentage(task) + " · " + status(task))
        .setColor(color)
        .setSortKey(String.format(Locale.ROOT, "%019d", Long.MAX_VALUE - task.created))
        .setOngoing(active(task))
        .setStyle(new Notification.DecoratedCustomViewStyle())
        .setCustomContentView(compact(task, graph, color))
        .setCustomBigContentView(content(task, graph, color));
  }

  private RemoteViews compact(DownloadTask task, Bitmap graph, int color) {
    RemoteViews views =
        new RemoteViews(context.getPackageName(), R.layout.notification_download_compact);
    views.setTextViewText(R.id.download_notification_compact_name, task.name);
    views.setTextViewText(
        R.id.download_notification_percent, percentage(task).replace(" completed", ""));
    views.setTextViewText(R.id.download_notification_compact_state, status(task));
    views.setTextColor(R.id.download_notification_compact_state, color);
    views.setImageViewBitmap(R.id.download_notification_compact_graph, graph);
    views.setOnClickPendingIntent(R.id.download_notification_compact, open);
    return views;
  }

  private RemoteViews content(DownloadTask task, Bitmap graph, int color) {
    RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.notification_download);
    views.setTextViewText(R.id.download_notification_name, task.name);
    views.setTextViewText(R.id.download_notification_size, size(task));
    views.setTextViewText(R.id.download_notification_state, status(task));
    views.setTextColor(R.id.download_notification_state, color);
    views.setImageViewBitmap(R.id.download_notification_graph, graph);
    views.setContentDescription(
        R.id.download_notification, task.name + ", " + size(task) + ", " + status(task));
    views.setOnClickPendingIntent(R.id.download_notification, open);
    return views;
  }

  private static int color(String state) {
    return switch (state) {
      case "complete" -> 0xFF16A34A;
      case "cancelled" -> 0xFFFBC02D;
      case "failed", "error" -> 0xFFDC2626;
      default -> 0xFF087CFA;
    };
  }

  private static String size(DownloadTask task) {
    return bytes(task.bytes) + (task.total > 0 ? " / " + bytes(task.total) : "");
  }

  private static String percentage(DownloadTask task) {
    if (task.state.equals("complete")) return "100% completed";
    if (task.total <= 0) return "Progress unknown";
    int percent = (int) Math.max(0, Math.min(100, (double) task.bytes / task.total * 100));
    return percent + "% completed";
  }

  private static String status(DownloadTask task) {
    if (task.state.equals("running") && !task.phase.isEmpty()) return task.phase;
    return task.state.equals("running")
        ? bytes(task.speed) + "/s"
        : task.state.substring(0, 1).toUpperCase(Locale.ROOT) + task.state.substring(1);
  }

  private static String bytes(long value) {
    if (value < 1024) return value + " B";
    if (value < 1048576) return String.format(Locale.ROOT, "%.1f KB", value / 1024.0);
    if (value < 1073741824) return String.format(Locale.ROOT, "%.1f MB", value / 1048576.0);
    return String.format(Locale.ROOT, "%.2f GB", value / 1073741824.0);
  }

  private static Bitmap graph(DownloadTask task, int color) {
    final int width = 640, height = 112;
    Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
    Canvas canvas = new Canvas(bitmap);
    List<List<Double>> history = task.graphHistory();
    double progress =
        task.state.equals("complete")
            ? 1
            : task.total > 0 ? Math.max(0, Math.min(1, (double) task.bytes / task.total)) : 0;
    if (history.isEmpty())
      history = Arrays.asList(Arrays.asList(0.0, 0.0), Arrays.asList(progress, 0.0));
    double peak = 1;
    for (List<Double> point : history) peak = Math.max(peak, point.get(1));
    float top = height * .10f, bottom = height * .75f;
    List<PointF> points = new ArrayList<>();
    for (List<Double> point : history)
      points.add(
          new PointF(
              (float) (width * Math.max(0, Math.min(1, point.get(0)))),
              bottom - (float) (Math.max(0, Math.min(1, point.get(1) / peak)) * (bottom - top))));
    Path line = new Path();
    line.moveTo(points.get(0).x, points.get(0).y);
    for (int i = 1; i < points.size(); i++) {
      PointF previous = points.get(i - 1), current = points.get(i);
      PointF before = points.get(Math.max(0, i - 2)),
          after = points.get(Math.min(points.size() - 1, i + 1));
      float segment = (current.x - previous.x) / 3;
      line.cubicTo(
          previous.x + segment,
          Math.max(top, Math.min(bottom, previous.y + (current.y - before.y) / 6)),
          current.x - segment,
          Math.max(top, Math.min(bottom, current.y - (after.y - previous.y) / 6)),
          current.x,
          current.y);
    }
    Path area = new Path(line);
    area.lineTo(points.get(points.size() - 1).x, height);
    area.lineTo(0, height);
    area.close();
    Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    fill.setShader(
        new LinearGradient(
            0,
            top,
            0,
            height,
            (color & 0xFFFFFF) | 0x2E000000,
            color & 0xFFFFFF,
            Shader.TileMode.CLAMP));
    canvas.drawPath(area, fill);
    Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    stroke.setColor(color);
    stroke.setStyle(Paint.Style.STROKE);
    stroke.setStrokeWidth(2.5f);
    stroke.setStrokeCap(Paint.Cap.ROUND);
    stroke.setStrokeJoin(Paint.Join.ROUND);
    canvas.drawPath(line, stroke);
    return bitmap;
  }
}
