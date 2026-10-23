package com.example.crocbrowser.media;

import android.app.*;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.BitmapFactory;
import android.media.*;
import android.media.session.*;
import android.net.Uri;
import android.os.IBinder;
import com.example.crocbrowser.R;

public final class BackgroundMediaService extends Service {
  private androidx.media3.exoplayer.ExoPlayer player;
  private Intent sourceIntent;
  private MediaSession session;
  private Uri uri;

  @Override
  public void onCreate() {
    super.onCreate();
    getSystemService(NotificationManager.class)
        .createNotificationChannel(
            new NotificationChannel(
                "croc_media", "Crock media playback", NotificationManager.IMPORTANCE_LOW));
    session = new MediaSession(this, "Crock Player");
    session.setCallback(
        new MediaSession.Callback() {
          @Override
          public void onPlay() {
            if (player != null) {
              player.play();
              notifyState();
            }
          }

          @Override
          public void onPause() {
            if (player != null) {
              player.pause();
              notifyState();
            }
          }

          @Override
          public void onStop() {
            stopSelf();
          }

          @Override
          public void onSeekTo(long position) {
            if (player != null) player.seekTo(position);
          }
        });
    session.setActive(true);
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int id) {
    if (intent == null) {
      stopSelf();
      return START_NOT_STICKY;
    }
    if ("stop".equals(intent.getAction())) {
      stopSelf();
      return START_NOT_STICKY;
    }
    if ("toggle".equals(intent.getAction())) {
      if (player != null) {
        if (player.isPlaying()) player.pause();
        else player.play();
        notifyState();
      }
      return START_NOT_STICKY;
    }
    uri = intent.getData();
    startForeground(715, notification(false), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
    try {
      if (player != null) player.release();
      sourceIntent = new Intent(intent);
      player = MediaSources.create(this, intent);
      player.addListener(
          new androidx.media3.common.Player.Listener() {
            @Override
            public void onIsPlayingChanged(boolean playing) {
              notifyState();
            }

            @Override
            public void onPlaybackStateChanged(int state) {
              if (state == androidx.media3.common.Player.STATE_ENDED) stopSelf();
            }

            @Override
            public void onPlayerError(androidx.media3.common.PlaybackException error) {
              stopSelf();
            }
          });
      notifyState();
    } catch (Exception error) {
      stopSelf();
    }
    return START_NOT_STICKY;
  }

  private void notifyState() {
    boolean playing = player != null && player.isPlaying();
    session.setPlaybackState(
        new PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY_PAUSE
                    | PlaybackState.ACTION_STOP
                    | PlaybackState.ACTION_SEEK_TO)
            .setState(
                playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
                player == null ? 0 : player.getCurrentPosition(),
                1)
            .build());
    getSystemService(NotificationManager.class).notify(715, notification(playing));
  }

  private Notification notification(boolean playing) {
    PendingIntent open =
        PendingIntent.getActivity(
            this,
            10,
            new Intent(this, MediaPlayerActivity.class)
                .setData(uri)
                .putExtra(
                    "downloadId",
                    sourceIntent == null ? null : sourceIntent.getStringExtra("downloadId"))
                .putExtra(
                    "headers", sourceIntent == null ? null : sourceIntent.getStringExtra("headers"))
                .putExtra("position", player == null ? 0L : player.getCurrentPosition()),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    PendingIntent toggle =
        PendingIntent.getService(
            this,
            11,
            new Intent(this, BackgroundMediaService.class).setAction("toggle"),
            PendingIntent.FLAG_IMMUTABLE);
    PendingIntent stop =
        PendingIntent.getService(
            this,
            12,
            new Intent(this, BackgroundMediaService.class).setAction("stop"),
            PendingIntent.FLAG_IMMUTABLE);
    return new Notification.Builder(this, "croc_media")
        .setSmallIcon(R.drawable.ic_notification_crock)
        .setLargeIcon(BitmapFactory.decodeResource(getResources(), R.drawable.crock_logo))
        .setContentTitle("Crock Player")
        .setContentText(playing ? "Playing in the background" : "Paused")
        .setContentIntent(open)
        .setOngoing(playing)
        .addAction(
            new Notification.Action.Builder(null, playing ? "Pause" : "Play", toggle).build())
        .addAction(new Notification.Action.Builder(null, "Stop", stop).build())
        .setStyle(
            new Notification.MediaStyle()
                .setMediaSession(session.getSessionToken())
                .setShowActionsInCompactView(0, 1))
        .build();
  }

  @Override
  public void onDestroy() {
    if (player != null) player.release();
    session.release();
    stopForeground(STOP_FOREGROUND_REMOVE);
    super.onDestroy();
  }

  @Override
  public IBinder onBind(Intent intent) {
    return null;
  }
}
