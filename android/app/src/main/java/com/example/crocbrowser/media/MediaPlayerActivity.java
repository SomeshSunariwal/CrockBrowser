package com.example.crocbrowser.media;

import android.app.*;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Rational;
import android.view.*;
import android.widget.*;
import androidx.media3.common.*;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;
import com.example.crocbrowser.R;

/** Branded player with adaptive streams, speed, PiP and background audio. */
@androidx.annotation.OptIn(markerClass = androidx.media3.common.util.UnstableApi.class)
public final class MediaPlayerActivity extends Activity {
  private ExoPlayer player;
  private LinearLayout controls, actions;
  private PlayerView surface;

  private int dp(int value) {
    return Math.round(value * getResources().getDisplayMetrics().density);
  }

  private void styleButton(Button button) {
    button.setAllCaps(false);
    button.setTextColor(Color.WHITE);
    button.setTextSize(13);
    button.setMinWidth(0);
    button.setMinimumWidth(0);
    button.setMinHeight(dp(44));
    button.setMinimumHeight(dp(44));
    button.setPadding(dp(8), dp(8), dp(8), dp(8));
    android.graphics.drawable.GradientDrawable shape =
        new android.graphics.drawable.GradientDrawable();
    shape.setColor(Color.rgb(25, 38, 54));
    shape.setCornerRadius(dp(14));
    button.setBackground(
        new android.graphics.drawable.RippleDrawable(
            android.content.res.ColorStateList.valueOf(Color.rgb(44, 68, 97)), shape, null));
  }

  private LinearLayout.LayoutParams actionLayout() {
    LinearLayout.LayoutParams layout = new LinearLayout.LayoutParams(0, dp(48), 1);
    layout.setMargins(dp(4), 0, dp(4), 0);
    return layout;
  }

  @Override
  public void onCreate(Bundle state) {
    super.onCreate(state);
    LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setBackgroundColor(Color.BLACK);
    root.setOnApplyWindowInsetsListener(
        (view, insets) -> {
          android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
          view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
          return insets;
        });
    controls = new LinearLayout(this);
    controls.setGravity(Gravity.CENTER_VERTICAL);
    controls.setPadding(dp(16), dp(12), dp(16), dp(8));
    ImageView logo = new ImageView(this);
    logo.setImageResource(R.drawable.crock_logo);
    controls.addView(logo, new LinearLayout.LayoutParams(dp(40), dp(40)));
    TextView title = new TextView(this);
    title.setText("  Crock Player");
    title.setTextColor(Color.WHITE);
    title.setTextSize(18);
    controls.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
    Button close = new Button(this);
    styleButton(close);
    close.setText("Close");
    close.setOnClickListener(v -> finish());
    controls.addView(close);
    root.addView(controls);
    surface = new PlayerView(this);
    root.addView(surface, new LinearLayout.LayoutParams(-1, 0, 1));
    actions = new LinearLayout(this);
    actions.setPadding(dp(8), dp(8), dp(8), dp(12));
    Button rate = new Button(this);
    styleButton(rate);
    rate.setText("Speed 1×");
    rate.setOnClickListener(
        v -> {
          String[] labels = {"0.5×", "0.75×", "1×", "1.25×", "1.5×", "2×"};
          float[] values = {.5f, .75f, 1, 1.25f, 1.5f, 2};
          new AlertDialog.Builder(this)
              .setTitle("Playback speed")
              .setItems(
                  labels,
                  (d, index) -> {
                    if (player != null) {
                      player.setPlaybackSpeed(values[index]);
                      rate.setText(labels[index]);
                    }
                  })
              .show();
        });
    actions.addView(rate, actionLayout());
    Button pip = new Button(this);
    styleButton(pip);
    pip.setText("Mini player");
    pip.setOnClickListener(
        v -> {
          try {
            enterPictureInPictureMode(
                new PictureInPictureParams.Builder().setAspectRatio(new Rational(16, 9)).build());
          } catch (Exception e) {
            Toast.makeText(this, "Picture in picture is unavailable", Toast.LENGTH_SHORT).show();
          }
        });
    actions.addView(pip, actionLayout());
    Button background = new Button(this);
    styleButton(background);
    background.setText("Background");
    background.setOnClickListener(
        v -> {
          if (player == null) return;
          Intent intent =
              new Intent(this, BackgroundMediaService.class)
                  .setData(getIntent().getData())
                  .putExtra("position", player.getCurrentPosition())
                  .putExtra("speed", player.getPlaybackParameters().speed)
                  .putExtra("downloadId", getIntent().getStringExtra("downloadId"))
                  .putExtra("headers", getIntent().getStringExtra("headers"));
          player.pause();
          startForegroundService(intent);
          finish();
        });
    actions.addView(background, actionLayout());
    root.addView(actions);
    setContentView(root);
    stopService(new Intent(this, BackgroundMediaService.class));
    try {
      if (state != null) getIntent().putExtra("position", state.getLong("position"));
      player = MediaSources.create(this, getIntent());
      surface.setPlayer(player);
      player.addListener(
          new Player.Listener() {
            @Override
            public void onPlayerError(PlaybackException error) {
              boolean decoderError = error.errorCode >= 4000 && error.errorCode < 5000;
              AlertDialog.Builder dialog =
                  new AlertDialog.Builder(MediaPlayerActivity.this)
                      .setTitle("Cannot play this media")
                      .setMessage(
                          decoderError
                              ? "Your device's decoder could not play this clip. Try software"
                                  + " playback."
                              : "This media could not be read. It may be incomplete or use an"
                                  + " unsupported format.")
                      .setPositiveButton("Close", (d, w) -> finish());
              if (decoderError && !getIntent().getBooleanExtra("softwareDecoder", false)) {
                dialog.setNeutralButton(
                    "Software playback",
                    (d, w) -> {
                      getIntent().putExtra("softwareDecoder", true);
                      recreate();
                    });
              }
              dialog.show();
            }
          });
    } catch (Exception error) {
      Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show();
      finish();
    }
  }

  @Override
  public void onPictureInPictureModeChanged(
      boolean inPip, android.content.res.Configuration config) {
    super.onPictureInPictureModeChanged(inPip, config);
    controls.setVisibility(inPip ? View.GONE : View.VISIBLE);
    actions.setVisibility(inPip ? View.GONE : View.VISIBLE);
    surface.setUseController(!inPip);
  }

  @Override
  protected void onSaveInstanceState(Bundle state) {
    if (player != null) state.putLong("position", player.getCurrentPosition());
    super.onSaveInstanceState(state);
  }

  @Override
  protected void onStart() {
    super.onStart();
    if (player != null) player.play();
  }

  @Override
  protected void onStop() {
    if (player != null && !isInPictureInPictureMode()) player.pause();
    super.onStop();
  }

  @Override
  protected void onDestroy() {
    if (player != null) player.release();
    super.onDestroy();
  }
}
