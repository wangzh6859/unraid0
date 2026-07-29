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
  bool _arrayBusy = false;

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

  Future<void> _toggleArray(bool start) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(start ? '启动阵列？' : '停止阵列？'),
        content: Text(
          start
              ? '这会挂载所有磁盘并启动阵列。'
              : '停止阵列会先停掉所有 Docker 容器和虚拟机，确认要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(start ? '启动' : '停止',
                style: TextStyle(color: start ? AppColors.green : AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _arrayBusy = true);
    try {
      await widget.api.setArrayState(start);
      await _load();
    } on UnraidApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _arrayBusy = false);
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

    final stats = _stats!;
    final cpuTemp = stats.cpuAvgTemp;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.orange,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ------- 顶部：主机名 + 运行时间（不再单独占一个方块） -------
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
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.timelapse_rounded, size: 15, color: Colors.black87),
                          const SizedBox(width: 5),
                          Text(
                            '已运行 ${stats.uptimeLabel}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.dns_rounded, color: Colors.black, size: 36),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ------- 阵列状态 + 启停控制 -------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _arrayColor(stats.arrayState), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '磁盘阵列 · ${_arrayLabel(stats.arrayState)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                if (_arrayBusy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else if (stats.arrayState == 'STARTED')
                  TextButton.icon(
                    onPressed: () => _toggleArray(false),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('停止'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  )
                else if (stats.arrayState == 'STOPPED')
                  TextButton.icon(
                    onPressed: () => _toggleArray(true),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: const Text('启动'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.green),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ------- CPU / 内存 环形使用率 -------
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
                  centerLabel: '${stats.cpuCores}核${stats.cpuThreads}线程',
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

          // ------- 详细信息网格 -------
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              StatCard(
                title: 'CPU 温度',
                value: cpuTemp != null ? '${cpuTemp.toStringAsFixed(0)}°C' : '暂不支持',
                icon: Icons.thermostat_rounded,
                gradient: AppColors.gradientPrimary,
                subtitle: cpuTemp == null ? '需要主板传感器数据' : null,
              ),
              StatCard(
                title: 'CPU 型号',
                value: stats.cpuBrand.isNotEmpty
                    ? stats.cpuBrand.split(' ').take(3).join(' ')
                    : '未知',
                icon: Icons.developer_board_rounded,
                gradient: AppColors.gradientBlue,
                subtitle: stats.cpuManufacturer.isNotEmpty ? stats.cpuManufacturer : null,
              ),
              StatCard(
                title: '内存占用',
                value: stats.memUsedLabel,
                icon: Icons.memory_rounded,
                gradient: AppColors.gradientTeal,
                subtitle: '共 ${stats.memTotalLabel}',
              ),
              StatCard(
                title: 'GPU',
                value: stats.gpus.isNotEmpty ? stats.gpus.first.displayName : '未检测到',
                icon: Icons.videogame_asset_rounded,
                gradient: LinearGradient(
                    colors: [AppColors.blue, AppColors.blue.withValues(alpha: 0.6)]),
                subtitle: '官方 API 暂不提供占用率',
              ),
            ],
          ),

          // ------- 网络接口（官方 API 只有链路状态，没有实时速率） -------
          if (stats.networkInterfaces.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: const [
                Text('网络接口',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(width: 8),
                Tooltip(
                  message: '官方 API 暂不提供实时上传/下载速率，这里显示的是连接状态',
                  child: Icon(Icons.info_outline_rounded, size: 15, color: AppColors.textFaint),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...stats.networkInterfaces.map((n) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 10, color: n.isConnected ? AppColors.green : AppColors.textFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(n.name,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      ),
                      Text(n.ipAddress ?? (n.isConnected ? '已连接' : '未连接'),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )),
          ],

          // ------- 磁盘列表：温度 + 容量 + 健康状态 -------
          if (stats.disks.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '磁盘状态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            ...stats.disks.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle,
                              size: 9, color: d.isHealthy ? AppColors.green : AppColors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(d.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (d.tempC != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Text('${d.tempC}°C',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (d.isHealthy ? AppColors.green : AppColors.red)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d.healthLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: d.isHealthy ? AppColors.green : AppColors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (d.fsSizeKb > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: d.usedPercent / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '已用 ${d.usedLabel} / 共 ${d.totalLabel}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                        ),
                      ],
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
