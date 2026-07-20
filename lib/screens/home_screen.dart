import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/storage_service.dart';
import '../services/unraid_api.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'docker_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  UnraidApi? _api;
  final _storage = StorageService();
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final saved = await _storage.loadConnection();
    if (saved == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() {
      _api = UnraidApi(
        host: saved['host'],
        apiKey: saved['apiKey'],
        useHttps: saved['useHttps'] ?? false,
      );
    });
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService().checkForUpdate();
    if (mounted && info != null) {
      setState(() => _updateInfo = info);
    }
  }

  Future<void> _logout() async {
    await _storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_api == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screens = [
      DashboardScreen(api: _api!),
      DockerScreen(api: _api!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? '仪表盘' : 'Docker 容器'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: '断开连接',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_updateInfo != null) _buildUpdateBanner(_updateInfo!),
          Expanded(child: screens[_tabIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.speed_rounded),
            label: '仪表盘',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.widgets_rounded),
            label: 'Docker',
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(UpdateInfo info) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '发现新版本 ${info.latestVersion}，点击下载安装',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse(info.downloadUrl), mode: LaunchMode.externalApplication),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('更新', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
