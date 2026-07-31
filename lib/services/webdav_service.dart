import 'dart:io';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// 对接 WebDAV 服务（比如你已经装好的 OpenList）的客户端封装。
///
/// 这是完全独立于 GraphQL API 的一套连接——用你在 OpenList 里设置的
/// WebDAV 地址 + 账号密码登录，不涉及 Unraid 本身的 root/SSH 权限。
class WebdavException implements Exception {
  final String message;
  WebdavException(this.message);
  @override
  String toString() => message;
}

class WebdavCredentials {
  final String url; // 例如 http://192.168.1.10:5244/dav
  final String username;
  final String password;

  WebdavCredentials({
    required this.url,
    required this.username,
    required this.password,
  });
}

/// 简化后的文件/文件夹条目，屏蔽掉 webdav_client 底层类型细节。
class WebdavEntry {
  final String name;
  final String path; // 相对路径，用于后续操作（下载/删除/重命名等）
  final bool isDir;
  final int sizeBytes;
  final DateTime? modifiedAt;

  WebdavEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get sizeLabel {
    if (isDir) return '';
    if (sizeBytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = sizeBytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  /// 根据文件名后缀粗略分类，决定用什么方式预览
  WebdavFileKind get kind {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
    const textExts = {
      'txt', 'md', 'json', 'yml', 'yaml', 'xml', 'log', 'ini', 'conf', 'sh', 'dart', 'js', 'ts', 'py', 'html', 'css'
    };
    const videoExts = {'mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v'};
    if (imageExts.contains(ext)) return WebdavFileKind.image;
    if (textExts.contains(ext)) return WebdavFileKind.text;
    if (videoExts.contains(ext)) return WebdavFileKind.video;
    return WebdavFileKind.other;
  }
}

enum WebdavFileKind { image, text, video, other }

class WebdavService {
  final WebdavCredentials credentials;
  late final webdav.Client _client;

  WebdavService(this.credentials) {
    _client = webdav.newClient(
      credentials.url,
      user: credentials.username,
      password: credentials.password,
    );
    _client.setConnectTimeout(10000);
    _client.setSendTimeout(30000);
    _client.setReceiveTimeout(30000);
  }

  Future<void> testConnection() async {
    try {
      await _client.ping();
    } catch (e) {
      throw WebdavException('连接失败，请检查地址/账号/密码：$e');
    }
  }

  Future<List<WebdavEntry>> listDir(String path) async {
    try {
      final list = await _client.readDir(path.isEmpty ? '/' : path);
      final entries = list
          .where((f) => f.name != null && f.name!.isNotEmpty)
          .map((f) => WebdavEntry(
                name: f.name!,
                path: f.path ?? '$path/${f.name}',
                isDir: f.isDir ?? false,
                sizeBytes: f.size ?? 0,
                modifiedAt: f.mTime,
              ))
          .toList();
      // 文件夹在前，按名称排序
      entries.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return entries;
    } catch (e) {
      throw WebdavException('读取目录失败：$e');
    }
  }

  Future<void> createFolder(String path) async {
    try {
      await _client.mkdir(path);
    } catch (e) {
      throw WebdavException('新建文件夹失败：$e');
    }
  }

  Future<void> delete(String path, {required bool isDir}) async {
    try {
      await _client.remove(isDir ? '$path/' : path);
    } catch (e) {
      throw WebdavException('删除失败：$e');
    }
  }

  Future<void> rename(String oldPath, String newPath, {required bool isDir}) async {
    try {
      await _client.rename(
        isDir ? '$oldPath/' : oldPath,
        isDir ? '$newPath/' : newPath,
        overwrite: false,
      );
    } catch (e) {
      throw WebdavException('重命名失败：$e');
    }
  }

  /// 下载到本地文件，onProgress 回调 0.0~1.0 的进度
  Future<void> downloadToFile(
    String remotePath,
    String localPath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _client.read2File(
        remotePath,
        localPath,
        onProgress: (count, total) {
          if (onProgress != null && total > 0) {
            onProgress(count / total);
          }
        },
      );
    } catch (e) {
      throw WebdavException('下载失败：$e');
    }
  }

  /// 上传本地文件到远程路径，onProgress 回调 0.0~1.0 的进度
  Future<void> uploadFromFile(
    File localFile,
    String remotePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _client.writeFromFile(
        localFile.path,
        remotePath,
        onProgress: (count, total) {
          if (onProgress != null && total > 0) {
            onProgress(count / total);
          }
        },
      );
    } catch (e) {
      throw WebdavException('上传失败：$e');
    }
  }

  /// 读取文件全部内容到内存（小文件预览用，比如文本文件）
  Future<List<int>> readBytes(String remotePath) async {
    try {
      return await _client.read(remotePath);
    } catch (e) {
      throw WebdavException('读取文件失败：$e');
    }
  }
}
