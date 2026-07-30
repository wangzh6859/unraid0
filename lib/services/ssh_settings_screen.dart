import 'package:flutter/material.dart';
import '../services/ssh_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SshSettingsScreen extends StatefulWidget {
  const SshSettingsScreen({super.key});

  @override
  State<SshSettingsScreen> createState() => _SshSettingsScreenState();
}

class _SshSettingsScreenState extends State<SshSettingsScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  final _storage = StorageService();

  bool _loading = false;
  bool _testing = false;
  String? _message;
  bool _messageIsError = false;
  bool _hasSavedCreds = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final creds = await _storage.loadSsh();
    if (creds != null && mounted) {
      setState(() {
        _hostController.text = creds.host;
        _portController.text = '${creds.port}';
        _usernameController.text = creds.username;
        _passwordController.text = creds.password ?? '';
        _hasSavedCreds = true;
      });
    }
  }

  SshCredentials? _buildCredentials() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (host.isEmpty || username.isEmpty) return null;
    return SshCredentials(
      host: host,
      port: port,
      username: username,
      password: password.isNotEmpty ? password : null,
    );
  }

  Future<void> _testConnection() async {
    final creds = _buildCredentials();
    if (creds == null) {
      setState(() {
        _message = '请填写主机地址和用户名';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      await SshService(creds).testConnection();
      if (!mounted) return;
      setState(() {
        _message = '连接成功！';
        _messageIsError = false;
      });
    } on SshException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final creds = _buildCredentials();
    if (creds == null) {
      setState(() {
        _message = '请填写主机地址和用户名';
        _messageIsError = true;
      });
      return;
    }
    setState(() => _loading = true);
    await _storage.saveSsh(creds);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasSavedCreds = true;
      _message = '已保存';
      _messageIsError = false;
    });
    Navigator.of(context).pop(true);
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('移除 SSH 配置？'),
        content: const Text('移除后，重启/关机、实时网速等依赖 SSH 的功能会不可用，其余功能不受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.clearSsh();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSH 连接设置')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '这是可选功能，用来实现官方 API 拿不到的东西：整机重启/关机、实时网速、完整 SMART 报告、文件管理。'
                '不填这里，App 其余功能完全不受影响。',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '⚠️ SSH 凭据风险比 API Key 高很多（等于拿到整台 NAS 的 root 权限），建议单独设置一个仅用于此的用户，并优先用密钥而非密码。',
                style: TextStyle(color: AppColors.yellow, height: 1.5, fontSize: 12.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'NAS 地址',
                  hintText: '例如 192.168.1.10',
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'SSH 端口',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                keyboardType: TextInputType.number,
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
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_messageIsError ? AppColors.red : AppColors.green)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                        color: _messageIsError ? AppColors.red : AppColors.green, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2))
                      : const Text('测试连接'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                      : const Text('保存'),
                ),
              ),
              if (_hasSavedCreds) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _remove,
                    child: const Text('移除 SSH 配置', style: TextStyle(color: AppColors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
