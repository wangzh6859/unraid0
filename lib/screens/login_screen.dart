import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/unraid_api.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _storage = StorageService();

  bool _useHttps = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final saved = await _storage.loadConnection();
    if (saved != null && mounted) {
      setState(() {
        _hostController.text = saved['host'];
        _apiKeyController.text = saved['apiKey'];
        _useHttps = saved['useHttps'] ?? false;
      });
    }
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (host.isEmpty || apiKey.isEmpty) {
      setState(() => _error = '请填写 NAS 地址和 API Key');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final api = UnraidApi(host: host, apiKey: apiKey, useHttps: _useHttps);
    try {
      await api.testConnection();
      await _storage.saveConnection(
        host: host,
        apiKey: apiKey,
        useHttps: _useHttps,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on UnraidApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.dns_rounded,
                    color: Colors.black, size: 32),
              ),
              const SizedBox(height: 24),
              const Text(
                '连接你的 Unraid',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '在 Unraid WebGUI 的 设置 → Management Access → API Keys 中生成密钥',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'NAS 地址',
                  hintText: '例如 192.168.1.10',
                  prefixIcon: Icon(Icons.router_rounded),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  prefixIcon: Icon(Icons.vpn_key_rounded),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _useHttps,
                    activeColor: AppColors.orange,
                    onChanged: (v) => setState(() => _useHttps = v),
                  ),
                  const Text('使用 HTTPS',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.black,
                          ),
                        )
                      : const Text('连接'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
