import 'package:shared_preferences/shared_preferences.dart';
import 'webdav_service.dart';

/// 负责在设备本地保存/读取连接信息。
///
/// 注意：这里使用 SharedPreferences（明文存储在应用私有目录），
/// 对于个人局域网/家庭场景足够方便。如果你希望更强的安全性，
/// 可以后续替换为 flutter_secure_storage。
class StorageService {
  static const _keyHost = 'unraid_host';
  static const _keyApiKey = 'unraid_api_key';
  static const _keyUseHttps = 'unraid_use_https';

  static const _keyWebdavUrl = 'webdav_url';
  static const _keyWebdavUsername = 'webdav_username';
  static const _keyWebdavPassword = 'webdav_password';

  static const _keyCacheLimitMb = 'cache_limit_mb';
  static const _defaultCacheLimitMb = 500;

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
    await clearWebdav();
  }

  // -------------------- WebDAV（文件管理，比如 OpenList）--------------------

  Future<void> saveWebdav(WebdavCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWebdavUrl, creds.url);
    await prefs.setString(_keyWebdavUsername, creds.username);
    await prefs.setString(_keyWebdavPassword, creds.password);
  }

  Future<WebdavCredentials?> loadWebdav() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyWebdavUrl);
    final username = prefs.getString(_keyWebdavUsername);
    final password = prefs.getString(_keyWebdavPassword);
    if (url == null || url.isEmpty) return null;
    return WebdavCredentials(
      url: url,
      username: username ?? '',
      password: password ?? '',
    );
  }

  Future<void> clearWebdav() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWebdavUrl);
    await prefs.remove(_keyWebdavUsername);
    await prefs.remove(_keyWebdavPassword);
  }

  // -------------------- App 设置：文件预览/缓存上限（MB，可实时调整）--------------------

  Future<int> loadCacheLimitMb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCacheLimitMb) ?? _defaultCacheLimitMb;
  }

  Future<void> saveCacheLimitMb(int mb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCacheLimitMb, mb);
  }
}
