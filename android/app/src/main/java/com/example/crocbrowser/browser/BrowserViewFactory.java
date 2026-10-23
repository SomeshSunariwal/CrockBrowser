package com.example.crocbrowser.browser;

import android.content.Context;
import com.example.crocbrowser.core.HostChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Map;

public final class BrowserViewFactory extends PlatformViewFactory {
  private final HostChannel host;

  public BrowserViewFactory(HostChannel host) {
    super(StandardMessageCodec.INSTANCE);
    this.host = host;
  }

  @Override
  public PlatformView create(Context context, int id, Object arguments) {
    return new BrowserView(host, id, (Map<String, Object>) arguments);
  }
}
