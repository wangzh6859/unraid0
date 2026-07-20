import 'package:shared_preferences/shared_preferences.dart';

/// 负责在设备本地保存/读取连接信息。
///
/// 注意：这里使用 SharedPreferences（明文存储在应用私有目录），
/// 对于个人局域网/家庭场景足够方便。如果你希望更强的安全性，
/// 可以后续替换为 flutter_secure_storage。
class StorageService {
  static const _keyHost = 'unraid_host';
  static const _keyApiKey = 'unraid_api_key';
  static const _keyUseHttps = 'unraid_use_https';

  Future<void> saveConnection({
    required String host,
    required String apiKey,
    required bool useHttps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setBool(_keyUseHttps, useHttps);
  }

  Future<Map<String, dynamic>?> loadConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_keyHost);
    final apiKey = prefs.getString(_keyApiKey);
    if (host == null || apiKey == null || host.isEmpty || apiKey.isEmpty) {
      return null;
    }
    return {
      'host': host,
      'apiKey': apiKey,
      'useHttps': prefs.getBool(_keyUseHttps) ?? false,
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHost);
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyUseHttps);
  }
}
