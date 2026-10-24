import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/platform/native_bridge.dart';

class DownloadController extends ChangeNotifier {
  DownloadController() {
    _events = NativeBridge.instance.events.listen((event) {
      if (event['type'] == 'downloads') {
        final error = (event['error'] as String?)?.trim();
        lastError = error == null || error.isEmpty ? null : error;
        final pending = _pendingAdds.remove(event['requestId']);
        if (pending != null) {
          pending.complete(lastError?.isNotEmpty == true ? lastError : null);
        }
        final snapshot = event['tasksJson'];
        if (snapshot is String) {
          _snapshotVersion++;
          tasks = (jsonDecode(snapshot) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          loading = false;
          notifyListeners();
        } else {
          refresh();
        }
      }
    });
    refresh();
  }
  List<Map<String, dynamic>> tasks = [];
  String? lastError;
  bool loading = true;
  late StreamSubscription<Map<String, dynamic>> _events;
  final Map<String, Completer<String?>> _pendingAdds = {};
  int _snapshotVersion = 0;
  Future<void> refresh() async {
    final version = ++_snapshotVersion;
    try {
      final rows = await NativeBridge.instance.list('downloads.list');
      if (version == _snapshotVersion) tasks = rows;
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
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    await NativeBridge.instance.call('device.permissions', {
      'permissions': ['android.permission.POST_NOTIFICATIONS'],
    });
    final accepted = Completer<String?>();
    _pendingAdds[requestId] = accepted;
    try {
      await NativeBridge.instance.call('downloads.enqueue', {
        ...request,
        'requestId': requestId,
      });
      final error = await accepted.future.timeout(const Duration(seconds: 10));
      if (error != null) throw StateError(error);
      await refresh();
    } finally {
      _pendingAdds.remove(requestId);
    }
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
