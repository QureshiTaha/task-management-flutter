// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'model/cached_network_call.dart';

class _SharedStorage {
  late Box _box;
  Future<void> init() async {
    Directory path = await getApplicationSupportDirectory();
    Hive.init(path.path);
    _box = await Hive.openBox("task-management-iceweb");
  }

  Future<void> addNetworkCall(CachedNetworkCall networkCall) async {
    List<CachedNetworkCall> calls = pendingNetworkCalls();
    calls.add(networkCall);
    await _box.put("networkCalls", calls.map((e) => e.toMap()).toList());
  }

  List<CachedNetworkCall> pendingNetworkCalls() {
    List<dynamic> values = _box.get("networkCalls", defaultValue: []);
    return values.map((e) => CachedNetworkCall.fromMap(e)).toList();
  }

  Future<void> setLoggedIn(bool loggedIn) async {
    await _box.put("isLoggedIn", loggedIn);
  }

  bool isLoggedIn() {
    return _box.get("isLoggedIn", defaultValue: false);
  }

  String? getString(String key) {
    return _box.get(key);
  }

  Future<void> putString(String key, String? value) async {
    if (value == null) {
      await remove(key);
    } else {
      await _box.put(key, value);
    }
  }

  int? getInt(String key) {
    return _box.get(key);
  }

  Future<void> putInt(String key, int? value) async {
    if (value == null) {
      await remove(key);
    } else {
      await _box.put(key, value);
    }
  }

  Future<void> putObject(String key, Object? value) async {
    if (value == null) {
      await remove(key);
    } else {
      await _box.put(key, value);
    }
  }

  Object? getObject(String key) {
    return _box.get(key);
  }

  Future<void> remove(String key) {
    return _box.delete(key);
  }

  Future<void> clear() {
    return _box.clear();
  }

  Future<void> removeNetworkCall(CachedNetworkCall call) async {
    List<CachedNetworkCall> calls = pendingNetworkCalls();
    calls.removeWhere((e) => e.id == call.id);
    await _box.put("networkCalls", calls.map((e) => e.toMap()).toList());
  }
}

final localStorage = _SharedStorage();
