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
        final snapshot = event['tasksJson'];
        final pending = _pendingAdds.remove(event['requestId']);
        if (pending != null) {
          pending.complete(_AddReceipt(lastError, snapshot is String));
        }
        if (snapshot is String) {
          _snapshotVersion++;
          _applySnapshot(
            (jsonDecode(snapshot) as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList(),
          );
          loading = false;
          notifyListeners();
        } else if (pending == null) {
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
  final Map<String, Completer<_AddReceipt>> _pendingAdds = {};
  bool _requestedNotifications = false;
  int _snapshotVersion = 0;
  final _completed = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get completions => _completed.stream;
  final _completedIds = <String>{};
  bool _hasSnapshot = false;

  void _applySnapshot(List<Map<String, dynamic>> rows) {
    tasks = rows;
    for (final task in rows) {
      final id = task['id'] as String;
      if (task['state'] == 'complete' &&
          _completedIds.add(id) &&
          _hasSnapshot) {
        _completed.add(Map<String, dynamic>.from(task));
      }
    }
    _hasSnapshot = true;
  }

  Future<void> refresh() async {
    final version = ++_snapshotVersion;
    try {
      final rows = await NativeBridge.instance.list('downloads.list');
      if (version == _snapshotVersion) _applySnapshot(rows);
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
    // Android permits foreground transfers even when notification permission is
    // denied. The first permission dialog must not hold the transfer queue up.
    if (!_requestedNotifications) {
      _requestedNotifications = true;
      unawaited(
        NativeBridge.instance
            .call('device.permissions', {
              'permissions': ['android.permission.POST_NOTIFICATIONS'],
            })
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    final accepted = Completer<_AddReceipt>();
    _pendingAdds[requestId] = accepted;
    try {
      await NativeBridge.instance.call('downloads.enqueue', {
        ...request,
        'requestId': requestId,
      });
      final receipt = await accepted.future.timeout(
        const Duration(seconds: 10),
      );
      if (receipt.error != null) throw StateError(receipt.error!);
      if (!receipt.hasSnapshot) await refresh();
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
    _completed.close();
    super.dispose();
  }
}

class _AddReceipt {
  const _AddReceipt(this.error, this.hasSnapshot);
  final String? error;
  final bool hasSnapshot;
}
