import 'package:shared_preferences/shared_preferences.dart';
import 'ssh_service.dart';

/// 负责在设备本地保存/读取连接信息。
///
/// 注意：这里使用 SharedPreferences（明文存储在应用私有目录），
/// 对于个人局域网/家庭场景足够方便。如果你希望更强的安全性，
/// 可以后续替换为 flutter_secure_storage。
///
/// SSH 凭据风险比 API Key 更高（等于拿到整台 NAS 的 root 权限），
/// 所以 SSH 是完全可选的一套独立配置，不填就不影响其余功能。
class StorageService {
  static const _keyHost = 'unraid_host';
  static const _keyApiKey = 'unraid_api_key';
  static const _keyUseHttps = 'unraid_use_https';

  static const _keySshHost = 'ssh_host';
  static const _keySshPort = 'ssh_port';
  static const _keySshUsername = 'ssh_username';
  static const _keySshPassword = 'ssh_password';
  static const _keySshPrivateKey = 'ssh_private_key';

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
    await clearSsh();
  }

  // -------------------- SSH（可选）--------------------

  Future<void> saveSsh(SshCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySshHost, creds.host);
    await prefs.setInt(_keySshPort, creds.port);
    await prefs.setString(_keySshUsername, creds.username);
    if (creds.password != null) {
      await prefs.setString(_keySshPassword, creds.password!);
    } else {
      await prefs.remove(_keySshPassword);
    }
    if (creds.privateKey != null) {
      await prefs.setString(_keySshPrivateKey, creds.privateKey!);
    } else {
      await prefs.remove(_keySshPrivateKey);
    }
  }

  Future<SshCredentials?> loadSsh() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_keySshHost);
    if (host == null || host.isEmpty) return null;
    return SshCredentials(
      host: host,
      port: prefs.getInt(_keySshPort) ?? 22,
      username: prefs.getString(_keySshUsername) ?? 'root',
      password: prefs.getString(_keySshPassword),
      privateKey: prefs.getString(_keySshPrivateKey),
    );
  }

  Future<void> clearSsh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySshHost);
    await prefs.remove(_keySshPort);
    await prefs.remove(_keySshUsername);
    await prefs.remove(_keySshPassword);
    await prefs.remove(_keySshPrivateKey);
  }
}
