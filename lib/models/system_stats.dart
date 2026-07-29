class SystemStats {
  final String hostname;
  final String distro;
  final String uptime;

  final String cpuBrand;
  final String cpuManufacturer;
  final int cpuCores;
  final int cpuThreads;
  final double cpuPercent;
  final List<double> cpuPackageTemps; // °C，每个物理封装一个

  final double memPercent;
  final int memTotalBytes;
  final int memUsedBytes;

  final String arrayState;
  final List<ArrayDiskInfo> disks;

  final List<GpuInfo> gpus;
  final List<NetworkInterfaceInfo> networkInterfaces;

  SystemStats({
    required this.hostname,
    required this.distro,
    required this.uptime,
    required this.cpuBrand,
    required this.cpuManufacturer,
    required this.cpuCores,
    required this.cpuThreads,
    required this.cpuPercent,
    required this.cpuPackageTemps,
    required this.memPercent,
    required this.memTotalBytes,
    required this.memUsedBytes,
    required this.arrayState,
    required this.disks,
    required this.gpus,
    required this.networkInterfaces,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    final info = json['info'] ?? {};
    final os = info['os'] ?? {};
    final cpu = info['cpu'] ?? {};
    final packages = cpu['packages'] ?? {};
    final devices = info['devices'] ?? {};
    final gpuList = (devices['gpu'] as List?) ?? [];
    final netList = (devices['network'] as List?) ?? [];

    final metrics = json['metrics'] ?? {};
    final metricsCpu = metrics['cpu'] ?? {};
    final metricsMem = metrics['memory'] ?? {};

    final array = json['array'] ?? {};
    final disksJson = (array['disks'] as List?) ?? [];
    final cachesJson = (array['caches'] as List?) ?? [];

    return SystemStats(
      hostname: os['hostname'] ?? '未知主机',
      distro: os['distro'] ?? '',
      uptime: os['uptime'] ?? '',
      cpuBrand: cpu['brand'] ?? '未知 CPU',
      cpuManufacturer: cpu['manufacturer'] ?? '',
      cpuCores: _toInt(cpu['cores']),
      cpuThreads: _toInt(cpu['threads']),
      cpuPercent: _toDouble(metricsCpu['percentTotal']),
      cpuPackageTemps: ((packages['temp'] as List?) ?? [])
          .map((t) => _toDouble(t))
          .where((t) => t > 0)
          .toList(),
      memPercent: _toDouble(metricsMem['percentTotal']),
      memTotalBytes: _toInt(metricsMem['total']),
      memUsedBytes: _toInt(metricsMem['used']),
      arrayState: array['state'] ?? 'UNKNOWN',
      disks: [...disksJson, ...cachesJson]
          .map((d) => ArrayDiskInfo.fromJson(d as Map<String, dynamic>))
          .toList(),
      gpus: gpuList
          .map((g) => GpuInfo.fromJson(g as Map<String, dynamic>))
          .toList(),
      networkInterfaces: netList
          .map((n) => NetworkInterfaceInfo.fromJson(n as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  String get memUsedLabel => _formatBytes(memUsedBytes);
  String get memTotalLabel => _formatBytes(memTotalBytes);

  /// CPU 封装平均温度（没有传感器数据时返回 null，界面上要显示"暂不支持"）
  double? get cpuAvgTemp {
    if (cpuPackageTemps.isEmpty) return null;
    return cpuPackageTemps.reduce((a, b) => a + b) / cpuPackageTemps.length;
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 GB';
    const gb = 1024 * 1024 * 1024;
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }

  /// 把 ISO 格式的开机时间转换成"12 天 4 小时"这种易读文案
  String get uptimeLabel {
    if (uptime.isEmpty) return '--';
    try {
      final dt = DateTime.parse(uptime);
      final diff = DateTime.now().difference(dt);
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      if (days > 0) return '$days 天 $hours 小时';
      if (diff.inHours > 0) {
        return '${diff.inHours} 小时 ${diff.inMinutes % 60} 分钟';
      }
      return '${diff.inMinutes} 分钟';
    } catch (_) {
      return uptime;
    }
  }
}

class ArrayDiskInfo {
  final String name;
  final String device;
  final String status;
  final int? tempC;
  final String type;
  final int fsSizeKb; // 文件系统总容量（KB）
  final int fsUsedKb; // 文件系统已用容量（KB）

  ArrayDiskInfo({
    required this.name,
    required this.device,
    required this.status,
    required this.tempC,
    required this.type,
    required this.fsSizeKb,
    required this.fsUsedKb,
  });

  factory ArrayDiskInfo.fromJson(Map<String, dynamic> json) {
    return ArrayDiskInfo(
      name: json['name'] ?? json['device'] ?? '未知磁盘',
      device: json['device'] ?? '',
      status: json['status'] ?? 'DISK_NP',
      tempC: json['temp'] is int ? json['temp'] : null,
      type: json['type'] ?? 'DATA',
      fsSizeKb: SystemStats._toInt(json['fsSize']),
      fsUsedKb: SystemStats._toInt(json['fsUsed']),
    );
  }

  bool get isHealthy => status == 'DISK_OK';

  /// 中文健康状态文案
  String get healthLabel {
    switch (status) {
      case 'DISK_OK':
        return '健康';
      case 'DISK_NP':
        return '未安装';
      case 'DISK_NP_MISSING':
        return '缺失';
      case 'DISK_INVALID':
        return '无效';
      case 'DISK_WRONG':
        return '插错槽位';
      case 'DISK_DSBL':
      case 'DISK_NP_DSBL':
        return '已禁用';
      case 'DISK_DSBL_NEW':
        return '禁用(新盘)';
      case 'DISK_NEW':
        return '新磁盘';
      default:
        return status;
    }
  }

  double get usedPercent {
    if (fsSizeKb <= 0) return 0;
    return (fsUsedKb / fsSizeKb * 100).clamp(0, 100);
  }

  String get usedLabel => _formatKb(fsUsedKb);
  String get totalLabel => _formatKb(fsSizeKb);

  static String _formatKb(int kb) {
    if (kb <= 0) return '--';
    final gb = kb / 1024 / 1024;
    if (gb >= 1024) return '${(gb / 1024).toStringAsFixed(1)} TB';
    return '${gb.toStringAsFixed(0)} GB';
  }
}

class GpuInfo {
  final String type;
  final String? vendorName;

  GpuInfo({required this.type, required this.vendorName});

  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      type: json['type'] ?? '未知设备',
      vendorName: json['vendorname'],
    );
  }

  String get displayName => vendorName?.isNotEmpty == true ? vendorName! : type;
}

class NetworkInterfaceInfo {
  final String iface;
  final String? model;
  final String? speed;

  NetworkInterfaceInfo({
    required this.iface,
    required this.model,
    required this.speed,
  });

  factory NetworkInterfaceInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInterfaceInfo(
      iface: json['iface'] ?? '未知网卡',
      model: json['model'],
      speed: json['speed'],
    );
  }

  /// 官方 API 这里只暴露网卡协商链路速度（比如 "1000"），不是实时占用率
  String get speedLabel => (speed != null && speed!.isNotEmpty) ? '$speed Mbps' : '未知带宽';
}
