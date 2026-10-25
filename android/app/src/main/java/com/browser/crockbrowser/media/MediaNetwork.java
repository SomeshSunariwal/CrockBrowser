package com.browser.crockbrowser.media;

import android.content.Context;
import android.net.Uri;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import java.util.Iterator;
import java.util.concurrent.TimeUnit;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import org.json.JSONObject;

/** Carries page request context without leaking cookies or authorization through redirects. */
@androidx.annotation.OptIn(markerClass = androidx.media3.common.util.UnstableApi.class)
public final class MediaNetwork {
  public static DataSource.Factory factory(Context context, String source, JSONObject headers) {
    Uri origin = Uri.parse(source);
    OkHttpClient client =
        new OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(25, TimeUnit.SECONDS)
            .followSslRedirects(false)
            .addNetworkInterceptor(
                chain -> {
                  Request request = chain.request();
                  Request.Builder next = request.newBuilder();
                  boolean same =
                      request.url().scheme().equals(origin.getScheme())
                          && request
                              .url()
                              .host()
                              .equalsIgnoreCase(origin.getHost() == null ? "" : origin.getHost())
                          && request.url().port()
                              == (origin.getPort() < 0
                                  ? ("https".equals(origin.getScheme()) ? 443 : 80)
                                  : origin.getPort());
                  Iterator<String> keys = headers.keys();
                  while (keys.hasNext()) {
                    String key = keys.next();
                    String value = headers.optString(key);
                    if (key.equalsIgnoreCase("Host")
                        || key.equalsIgnoreCase("Range")
                        || key.contains("\r")
                        || key.contains("\n")
                        || value.contains("\r")
                        || value.contains("\n")) continue;
                    if ((key.equalsIgnoreCase("Cookie") || key.equalsIgnoreCase("Authorization"))
                        && !same) next.removeHeader(key);
                    else next.header(key, value);
                  }
                  return chain.proceed(next.build());
                })
            .build();
    return new DefaultDataSource.Factory(context, new OkHttpDataSource.Factory(client));
  }
}
