package com.example.crocbrowser.media;

import android.content.Context;
import android.content.Intent;
import androidx.media3.common.MediaItem;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import com.example.crocbrowser.downloads.*;

@androidx.annotation.OptIn(markerClass = androidx.media3.common.util.UnstableApi.class)
final class MediaSources {
  static ExoPlayer create(Context context, Intent intent) throws Exception {
    ExoPlayer.Builder builder = new ExoPlayer.Builder(context);
    String download = intent.getStringExtra("downloadId");
    MediaItem item = MediaItem.fromUri(intent.getData());
    builder.setMediaSourceFactory(
        new DefaultMediaSourceFactory(
            MediaNetwork.factory(
                context,
                intent.getData().toString(),
                new org.json.JSONObject(
                    intent.getStringExtra("headers") == null
                        ? "{}"
                        : intent.getStringExtra("headers")))));
    if (download != null) {
      DownloadTask found = null;
      for (DownloadTask task : new DownloadRepository(context).load())
        if (task.id.equals(download)) found = task;
      if (found == null || !found.state.equals("complete"))
        throw new IllegalArgumentException("Offline media is unavailable");
      builder.setMediaSourceFactory(
          new DefaultMediaSourceFactory(StreamDownloads.source(context, found, true)));
      item =
          new MediaItem.Builder()
              .setUri(found.url)
              .setMimeType(
                  found.url.contains(".mpd") ? "application/dash+xml" : "application/x-mpegURL")
              .build();
    }
    ExoPlayer player = builder.build();
    player.setAudioAttributes(
        new androidx.media3.common.AudioAttributes.Builder()
            .setUsage(androidx.media3.common.C.USAGE_MEDIA)
            .setContentType(androidx.media3.common.C.AUDIO_CONTENT_TYPE_MOVIE)
            .build(),
        true);
    player.setHandleAudioBecomingNoisy(true);
    player.setMediaItem(item);
    player.seekTo(intent.getLongExtra("position", 0));
    player.setPlaybackSpeed(intent.getFloatExtra("speed", 1));
    player.prepare();
    player.play();
    return player;
  }
}
