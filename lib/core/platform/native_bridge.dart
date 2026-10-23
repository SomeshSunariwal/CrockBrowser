import 'package:flutter/services.dart';

/// The UI never accesses Android services directly. Java implements this API.
class NativeBridge {
  NativeBridge._();
  static final instance = NativeBridge._();
  static const _methods = MethodChannel('croc/native');
  static const _events = EventChannel('croc/events');
  late final Stream<Map<String, dynamic>> events = _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map))
      .asBroadcastStream();

  Future<T?> call<T>(String method, [Map<String, dynamic>? arguments]) =>
      _methods.invokeMethod<T>(method, arguments);
  Future<List<Map<String, dynamic>>> list(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final result = await call<List<dynamic>>(method, arguments) ?? [];
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
