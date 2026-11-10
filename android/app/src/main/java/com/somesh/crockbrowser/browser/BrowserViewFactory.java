package com.somesh.crockbrowser.browser;

import android.content.Context;
import com.somesh.crockbrowser.core.HostChannel;
import com.somesh.crockbrowser.core.JsonCodec;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public final class BrowserViewFactory extends PlatformViewFactory {
  private final HostChannel host;

  public BrowserViewFactory(HostChannel host) {
    super(StandardMessageCodec.INSTANCE);
    this.host = host;
  }

  @Override
  public PlatformView create(Context context, int id, Object arguments) {
    return new BrowserView(host, id, JsonCodec.arguments(arguments));
  }
}
