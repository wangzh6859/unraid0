import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/webdav_service.dart';
import '../theme/app_theme.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _storage = StorageService();
  WebdavService? _webdav;
  bool _checkingSaved = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final creds = await _storage.loadWebdav();
    if (creds != null && mounted) {
      setState(() => _webdav = WebdavService(creds));
    }
    if (mounted) setState(() => _checkingSaved = false);
  }

  void _onLoggedIn(WebdavService service) {
    setState(() => _webdav = service);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('退出登录？'),
        content: const Text('会清除本地保存的 WebDAV 地址和密码，下次要重新输入。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.clearWebdav();
    if (mounted) setState(() => _webdav = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSaved) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_webdav == null) {
      return _WebdavLoginForm(onLoggedIn: _onLoggedIn);
    }
    return _FileBrowser(webdav: _webdav!, onLogout: _logout);
  }
}

// ============================== 登录表单 ==============================

class _WebdavLoginForm extends StatefulWidget {
  final void Function(WebdavService service) onLoggedIn;
  const _WebdavLoginForm({required this.onLoggedIn});

  @override
  State<_WebdavLoginForm> createState() => _WebdavLoginFormState();
}

class _WebdavLoginFormState extends State<_WebdavLoginForm> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = StorageService();

  bool _loading = false;
  String? _error;

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (url.isEmpty) {
      setState(() => _error = '请填写 WebDAV 地址');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final creds = WebdavCredentials(url: url, username: username, password: password);
    final service = WebdavService(creds);
    try {
      await service.testConnection();
      await _storage.saveWebdav(creds);
      if (!mounted) return;
      widget.onLoggedIn(service);
    } on WebdavException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.gradientTeal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.folder_rounded, color: Colors.black, size: 30),
            ),
            const SizedBox(height: 22),
            const Text(
              '连接文件管理',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '填写 OpenList（或其他 WebDAV 服务）的地址和账号密码。',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'WebDAV 地址',
                hintText: '例如 http://192.168.1.10:5244/dav',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _connect,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                    : const Text('连接'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================== 文件浏览器 ==============================

class _FileBrowser extends StatefulWidget {
  final WebdavService webdav;
  final VoidCallback onLogout;
  const _FileBrowser({required this.webdav, required this.onLogout});

  @override
  State<_FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<_FileBrowser> {
  String _path = '/';
  List<WebdavEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.webdav.listDir(_path);
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } on WebdavException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  void _enterFolder(WebdavEntry entry) {
    setState(() => _path = entry.path);
    _load();
  }

  bool get _atRoot => _path == '/' || _path.isEmpty;

  void _goUp() {
    if (_atRoot) return;
    final trimmed = _path.endsWith('/') ? _path.substring(0, _path.length - 1) : _path;
    final idx = trimmed.lastIndexOf('/');
    setState(() => _path = idx <= 0 ? '/' : trimmed.substring(0, idx));
    _load();
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final newPath = _atRoot ? '/$name' : '$_path/$name';
    try {
      await widget.webdav.createFolder(newPath);
      _load();
    } on WebdavException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  IconData _iconFor(WebdavEntry entry) {
    if (entry.isDir) return Icons.folder_rounded;
    switch (entry.kind) {
      case WebdavFileKind.image:
        return Icons.image_rounded;
      case WebdavFileKind.video:
        return Icons.movie_rounded;
      case WebdavFileKind.text:
        return Icons.description_rounded;
      case WebdavFileKind.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_atRoot ? '文件管理' : _path.split('/').last),
        leading: _atRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _goUp,
              ),
        automaticallyImplyLeading: !_atRoot,
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: '退出登录',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFolder,
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.create_new_folder_rounded, color: Colors.black),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('这个文件夹是空的', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.orange,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final entry = _entries[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              onTap: entry.isDir
                  ? () => _enterFolder(entry)
                  : () {
                      // 上传/下载/预览下一步再加，这里先给个提示
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('文件预览/下载功能下一步加上')),
                      );
                    },
              leading: Icon(_iconFor(entry),
                  color: entry.isDir ? AppColors.orange : AppColors.textSecondary),
              title: Text(entry.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
              subtitle: entry.isDir
                  ? null
                  : Text(entry.sizeLabel,
                      style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              trailing: entry.isDir
                  ? const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
