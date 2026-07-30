import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

/// SSH 通道 —— 专门用来补齐官方 GraphQL API 覆盖不到的功能：
/// 重启/关机、实时网速采样、完整 SMART 报告、文件管理。
///
/// 这是可选功能：不配置 SSH，App 其余部分（仪表盘/Docker/VM）完全不受影响。
class SshException implements Exception {
  final String message;
  SshException(this.message);
  @override
  String toString() => message;
}

class SshCredentials {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey; // PEM 格式私钥内容（可选，跟 password 二选一）

  SshCredentials({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'privateKey': privateKey,
      };

  factory SshCredentials.fromJson(Map<String, dynamic> json) {
    return SshCredentials(
      host: json['host'] ?? '',
      port: json['port'] ?? 22,
      username: json['username'] ?? 'root',
      password: json['password'],
      privateKey: json['privateKey'],
    );
  }
}

class SshService {
  final SshCredentials credentials;
  SshService(this.credentials);

  Future<SSHClient> _connect() async {
    try {
      final socket = await SSHSocket.connect(
        credentials.host,
        credentials.port,
      ).timeout(const Duration(seconds: 8));

      return SSHClient(
        socket,
        username: credentials.username,
        onPasswordRequest: credentials.password != null
            ? () => credentials.password!
            : null,
        identities: credentials.privateKey != null
            ? SSHKeyPair.fromPem(credentials.privateKey!)
            : null,
      );
    } on TimeoutException {
      throw SshException('SSH 连接超时，请检查地址/端口是否正确，以及 NAS 上 SSH 服务是否已开启');
    } catch (e) {
      throw SshException('SSH 连接失败：$e');
    }
  }

  /// 执行一条命令并返回标准输出（字符串）。
  Future<String> run(String command) async {
    SSHClient? client;
    try {
      client = await _connect();
      final result = await client.run(command).timeout(const Duration(seconds: 15));
      return utf8.decode(result, allowMalformed: true);
    } on SshException {
      rethrow;
    } catch (e) {
      throw SshException('命令执行失败：$e');
    } finally {
      client?.close();
    }
  }

  /// 校验 SSH 连接是否可用（用于设置页"测试连接"）。
  Future<void> testConnection() async {
    await run('echo ok');
  }

  /// 重启整机。注意：这是真正的系统级重启，调用前 UI 层必须做二次确认。
  Future<void> reboot() async {
    await run('reboot');
  }

  /// 关机。注意：这是真正的系统级关机，调用前 UI 层必须做二次确认。
  Future<void> shutdown() async {
    await run('poweroff');
  }
}
