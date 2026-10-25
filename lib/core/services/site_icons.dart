import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Icons come from the website itself, without a third-party favicon service.
abstract final class SiteIcons {
  static final changes = ValueNotifier<int>(0);
  static final _cache = <String, (DateTime, Future<Uint8List?>)>{};
  static final _bundled = <String, Future<Uint8List?>>{};
  static const _limit = 512 * 1024;

  static void remember(String url, Uint8List png) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        png.length > _limit) {
      return;
    }
    if (_cache.length >= 128) _cache.remove(_cache.keys.first);
    _cache[uri.origin] = (DateTime.now(), Future.value(png));
    changes.value++;
  }

  static Future<Uint8List?> load(String url, {bool allowNetwork = true}) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return Future.value();
    }
    final bundled = switch (uri.host.toLowerCase()) {
      'google.com' || 'www.google.com' || 'm.google.com' => 'google',
      'youtube.com' ||
      'www.youtube.com' ||
      'm.youtube.com' ||
      'youtu.be' => 'youtube',
      _ => null,
    };
    if (bundled != null) {
      return _bundled.putIfAbsent(bundled, () async {
        final data = await rootBundle.load('assets/site_icons/$bundled.png');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      });
    }
    final origin = uri.origin;
    final cached = _cache[origin];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(hours: 1)) {
      return cached.$2;
    }
    if (!allowNetwork) return Future.value();
    if (_cache.length >= 128) _cache.remove(_cache.keys.first);
    final future = _load(Uri.parse(origin));
    _cache[origin] = (DateTime.now(), future);
    return future;
  }

  static Future<Uint8List?> _load(Uri origin) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      for (final path in ['/favicon.png', '/apple-touch-icon.png']) {
        try {
          final data = await _get(client, origin.resolve(path));
          if (data == null) continue;
          final png = await _decodePngIcon(data);
          if (png != null) return png;
        } catch (_) {
          // A missing or malformed favicon must never interrupt browsing.
        }
      }
    } finally {
      client.close(force: true);
    }
    return null;
  }

  static Future<Uint8List?> _get(HttpClient client, Uri uri) async {
    for (var redirects = 0; redirects <= 3; redirects++) {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 4));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'image/png,image/x-icon,image/vnd.microsoft.icon;q=0.9,*/*;q=0.1',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) return null;
        final next = uri.resolve(location);
        if (!['https', 'http'].contains(next.scheme) ||
            next.host.isEmpty ||
            next.userInfo.isNotEmpty ||
            (uri.scheme == 'https' && next.scheme != 'https')) {
          return null;
        }
        // Cancel this response body before following the next redirect.
        final subscription = response.listen((_) {});
        await subscription.cancel();
        uri = next;
        continue;
      }
      if (response.statusCode != 200 || response.contentLength > _limit) {
        final subscription = response.listen((_) {});
        await subscription.cancel();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 4))) {
        if (bytes.length + chunk.length > _limit) return null;
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    }
    return null;
  }
}

Future<Uint8List?> _decodePngIcon(Uint8List bytes) async {
  try {
    if (bytes.length < 24 ||
        bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4e ||
        bytes[3] != 0x47) {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    final width = data.getUint32(16);
    final height = data.getUint32(20);
    if (width == 0 || height == 0 || width > 4096 || height > 4096) {
      return null;
    }

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 64,
      targetHeight: 64,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return png?.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}
