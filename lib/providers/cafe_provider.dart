import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloud_service.dart';
import '../services/data_repository.dart';
import '../services/database_service.dart';

/// Decides where data lives: this phone only, or a shared cafe (Firebase).
class CafeProvider extends ChangeNotifier {
  final CloudService _cloud;
  final LocalRepository _local;
  CafeProvider(this._cloud, this._local);

  DataRepository _repo = LocalRepository.instance;
  String? cafeCode;
  String deviceTag = '';
  bool isOwner = false;

  DataRepository get repo => _repo;
  bool get isShared => cafeCode != null;
  bool get sharingAvailable => _cloud.isConfigured;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString('cafe_code');
    if (code != null && await _cloud.init()) {
      cafeCode = code;
      deviceTag = p.getString('device_tag') ?? '';
      isOwner = p.getBool('is_owner') ?? false;
      _repo = CloudRepository(code);
    } else {
      _repo = _local;
    }
    notifyListeners();
  }

  Future<void> _use(CafeMembership m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cafe_code', m.cafeCode);
    await p.setString('device_tag', m.deviceTag);
    await p.setBool('is_owner', m.isOwner);
    cafeCode = m.cafeCode;
    deviceTag = m.deviceTag;
    isOwner = m.isOwner;
    _repo = CloudRepository(m.cafeCode);
    notifyListeners();
  }

  /// Owner: move this phone's menu, orders and shop details online.
  /// Throws [CloudException] with a friendly message on failure.
  Future<void> createCafe(
    String pin, {
    void Function(String)? onProgress,
  }) async {
    final m = await _cloud.createCafe(
      pin: pin,
      local: _local,
      onProgress: onProgress,
    );
    await _use(m);
  }

  /// Staff phone: join with cafe code + PIN.
  /// Throws [CloudException] with a friendly message on failure.
  Future<void> joinCafe(String code, String pin) async {
    final m = await _cloud.joinCafe(code: code, pin: pin);
    await _use(m);
  }

  Future<String?> readPin() async =>
      cafeCode == null ? null : _cloud.readPin(cafeCode!);

  /// Stop sharing on this phone. It goes back to its own (old) data.
  Future<void> leaveCafe() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('cafe_code');
    await p.remove('device_tag');
    await p.remove('is_owner');
    cafeCode = null;
    deviceTag = '';
    isOwner = false;
    _repo = _local;
    notifyListeners();
  }
}
