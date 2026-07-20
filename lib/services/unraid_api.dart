import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/system_stats.dart';
import '../models/docker_container.dart';

/// 与 Unraid 官方 GraphQL API 通信的客户端。
///
/// 接口文档：Settings → Management Access → Developer Options 中开启
/// GraphQL Sandbox 后，端点固定为 http(s)://<NAS地址>/graphql，
/// 鉴权通过请求头 `x-api-key` 传递。
class UnraidApiException implements Exception {
  final String message;
  UnraidApiException(this.message);
  @override
  String toString() => message;
}

class UnraidApi {
  final String host; // 例如 192.168.1.10 或 192.168.1.10:port
  final String apiKey;
  final bool useHttps;

  UnraidApi({required this.host, required this.apiKey, this.useHttps = false});

  Uri get _endpoint =>
      Uri.parse('${useHttps ? "https" : "http"}://$host/graphql');

  Future<Map<String, dynamic>> _post(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    http.Response resp;
    try {
      resp = await http
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
            },
            body: jsonEncode({
              'query': query,
              if (variables != null) 'variables': variables,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw UnraidApiException('无法连接到 NAS，请检查地址和网络：$e');
    }

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw UnraidApiException('API Key 无效或权限不足');
    }
    if (resp.statusCode != 200) {
      throw UnraidApiException('服务器返回错误：HTTP ${resp.statusCode}');
    }

    late Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw UnraidApiException('返回的数据格式无法解析，请确认 GraphQL 已开启');
    }

    if (body['errors'] != null) {
      final errors = body['errors'] as List;
      final msg = errors.isNotEmpty ? errors.first['message'] : '未知错误';
      throw UnraidApiException('接口返回错误：$msg');
    }

    return (body['data'] as Map<String, dynamic>?) ?? {};
  }

  /// 校验连接是否有效（用于登录页测试连接）。
  Future<String> testConnection() async {
    const query = r'''
      query TestConnection {
        info { os { hostname } }
      }
    ''';
    final data = await _post(query);
    return data['info']?['os']?['hostname'] ?? 'Unraid';
  }

  /// 拉取仪表盘数据：系统信息 + CPU/内存利用率 + 阵列状态。
  Future<SystemStats> fetchSystemStats() async {
    const query = r'''
      query Dashboard {
        info {
          os { hostname distro uptime }
          cpu { brand cores }
        }
        metrics {
          cpu { percentTotal }
          memory { percentTotal total used }
        }
        array {
          state
          disks { name status temp type }
        }
      }
    ''';
    final data = await _post(query);
    return SystemStats.fromJson(data);
  }

  /// 拉取 Docker 容器列表。
  Future<List<DockerContainerInfo>> fetchContainers() async {
    const query = r'''
      query Containers {
        docker {
          containers {
            id
            names
            image
            state
            status
            autoStart
            iconUrl
          }
        }
      }
    ''';
    final data = await _post(query);
    final list = (data['docker']?['containers'] as List?) ?? [];
    return list
        .map((c) => DockerContainerInfo.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> startContainer(String id) async {
    const query = r'''
      mutation StartContainer($id: PrefixedID!) {
        docker { start(id: $id) { id state } }
      }
    ''';
    await _post(query, variables: {'id': id});
  }

  Future<void> stopContainer(String id) async {
    const query = r'''
      mutation StopContainer($id: PrefixedID!) {
        docker { stop(id: $id) { id state } }
      }
    ''';
    await _post(query, variables: {'id': id});
  }

  Future<void> pauseContainer(String id) async {
    const query = r'''
      mutation PauseContainer($id: PrefixedID!) {
        docker { pause(id: $id) { id state } }
      }
    ''';
    await _post(query, variables: {'id': id});
  }

  Future<void> unpauseContainer(String id) async {
    const query = r'''
      mutation UnpauseContainer($id: PrefixedID!) {
        docker { unpause(id: $id) { id state } }
      }
    ''';
    await _post(query, variables: {'id': id});
  }
}
