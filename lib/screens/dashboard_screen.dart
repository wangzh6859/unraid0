import 'package:flutter/material.dart';
import '../models/system_stats.dart';
import '../services/unraid_api.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/usage_ring.dart';

class DashboardScreen extends StatefulWidget {
  final UnraidApi api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SystemStats? _stats;
  String? _error;
  bool _loading = true;

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
      final stats = await widget.api.fetchSystemStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } on UnraidApiException catch (e) {
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

  Color _arrayColor(String state) {
    switch (state) {
      case 'STARTED':
        return AppColors.green;
      case 'STOPPED':
        return AppColors.textFaint;
      default:
        return AppColors.yellow;
    }
  }

  String _arrayLabel(String state) {
    switch (state) {
      case 'STARTED':
        return '运行中';
      case 'STOPPED':
        return '已停止';
      case 'NEW_ARRAY':
        return '新阵列';
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textFaint),
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

    final stats = _stats!;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.orange,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.hostname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats.distro,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.dns_rounded, color: Colors.black, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                UsageRing(
                  label: 'CPU',
                  percent: stats.cpuPercent,
                  color: AppColors.orange,
                  centerLabel: '${stats.cpuCores}核',
                ),
                UsageRing(
                  label: '内存',
                  percent: stats.memPercent,
                  color: AppColors.teal,
                  centerLabel: stats.memTotalLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              StatCard(
                title: '磁盘阵列',
                value: _arrayLabel(stats.arrayState),
                icon: Icons.storage_rounded,
                gradient: LinearGradient(
                  colors: [
                    _arrayColor(stats.arrayState),
                    _arrayColor(stats.arrayState).withValues(alpha: 0.6),
                  ],
                ),
                subtitle: '${stats.disks.length} 块磁盘',
              ),
              StatCard(
                title: '内存占用',
                value: stats.memUsedLabel,
                icon: Icons.memory_rounded,
                gradient: AppColors.gradientTeal,
                subtitle: '共 ${stats.memTotalLabel}',
              ),
              StatCard(
                title: '运行时间',
                value: _shortUptime(stats.uptime),
                icon: Icons.timelapse_rounded,
                gradient: AppColors.gradientBlue,
              ),
              StatCard(
                title: 'CPU',
                value: stats.cpuBrand.split(' ').take(2).join(' '),
                icon: Icons.developer_board_rounded,
                gradient: AppColors.gradientPrimary,
              ),
            ],
          ),
          if (stats.disks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '磁盘状态',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...stats.disks.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: d.isHealthy ? AppColors.green : AppColors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(d.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14)),
                      ),
                      if (d.tempC != null)
                        Text('${d.tempC}°C',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _shortUptime(String iso) {
    if (iso.isEmpty) return '--';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays} 天';
      if (diff.inHours > 0) return '${diff.inHours} 小时';
      return '${diff.inMinutes} 分钟';
    } catch (_) {
      return iso;
    }
  }
}
