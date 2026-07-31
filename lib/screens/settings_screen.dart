import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  double _cacheLimitMb = 500;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.loadCacheLimitMb();
    if (mounted) {
      setState(() {
        _cacheLimitMb = saved.toDouble();
        _loading = false;
      });
    }
  }

  Future<void> _onChanged(double value) async {
    setState(() => _cacheLimitMb = value);
    // 实时保存，不用等用户点"确定"
    await _storage.saveCacheLimitMb(value.round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sd_storage_rounded,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          const Text(
                            '文件缓存上限',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _cacheLimitMb >= 1000
                                ? '${(_cacheLimitMb / 1000).toStringAsFixed(1)} GB'
                                : '${_cacheLimitMb.round()} MB',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '文件管理里预览/下载过的文件会缓存在本地，超过这个上限后会自动清理最早的缓存。拖动滑块实时生效，不用额外保存。',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textFaint, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.orange,
                          thumbColor: AppColors.orange,
                          inactiveTrackColor: AppColors.border,
                          overlayColor: AppColors.orange.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: _cacheLimitMb,
                          min: 50,
                          max: 5000,
                          divisions: 99,
                          onChanged: _onChanged,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('50 MB',
                              style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
                          Text('5 GB',
                              style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '更多设置项会陆续加到这里。',
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
    );
  }
}
