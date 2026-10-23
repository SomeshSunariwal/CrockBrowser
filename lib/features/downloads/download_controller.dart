import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/platform/native_bridge.dart';

class DownloadController extends ChangeNotifier {
  DownloadController() {
    _events = NativeBridge.instance.events.listen((event) {
      if (event['type'] == 'downloads') {
        lastError = event['error'] as String?;
        refresh();
      }
    });
    refresh();
  }
  List<Map<String, dynamic>> tasks = [];
  String? lastError;
  bool loading = true;
  late StreamSubscription<Map<String, dynamic>> _events;
  Future<void> refresh() async {
    try {
      tasks = await NativeBridge.instance.list('downloads.list');
    } catch (error) {
      lastError = error.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> add(Map<String, dynamic> request) async {
    final uri = Uri.tryParse(request['url']?.toString() ?? '');
    if (uri == null ||
        (!['http', 'https'].contains(uri.scheme) && uri.scheme != 'magnet') ||
        (uri.scheme != 'magnet' &&
            (uri.host.isEmpty || uri.userInfo.isNotEmpty))) {
      throw ArgumentError('Enter an HTTP, HTTPS or magnet download URL');
    }
    await NativeBridge.instance.call('device.permissions', {
      'permissions': ['android.permission.POST_NOTIFICATIONS'],
    });
    await NativeBridge.instance.call('downloads.enqueue', request);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await refresh();
  }

  Future<void> command(String id, String action) async {
    await NativeBridge.instance.call('downloads.command', {
      'id': id,
      'action': action,
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await refresh();
  }

  Future<Map<String, dynamic>> file(String id) async =>
      Map<String, dynamic>.from(
        await NativeBridge.instance.call<Map>('downloads.file', {'id': id}) ??
            {},
      );
  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }
}
