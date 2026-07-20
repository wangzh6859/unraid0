class SystemStats {
  final String hostname;
  final String distro;
  final String uptime;
  final String cpuBrand;
  final int cpuCores;
  final double cpuPercent;
  final double memPercent;
  final int memTotalBytes;
  final int memUsedBytes;
  final String arrayState;
  final List<ArrayDiskInfo> disks;

  SystemStats({
    required this.hostname,
    required this.distro,
    required this.uptime,
    required this.cpuBrand,
    required this.cpuCores,
    required this.cpuPercent,
    required this.memPercent,
    required this.memTotalBytes,
    required this.memUsedBytes,
    required this.arrayState,
    required this.disks,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    final info = json['info'] ?? {};
    final os = info['os'] ?? {};
    final cpu = info['cpu'] ?? {};
    final metrics = json['metrics'] ?? {};
    final metricsCpu = metrics['cpu'] ?? {};
    final metricsMem = metrics['memory'] ?? {};
    final array = json['array'] ?? {};
    final disksJson = (array['disks'] as List?) ?? [];

    return SystemStats(
      hostname: os['hostname'] ?? '未知主机',
      distro: os['distro'] ?? '',
      uptime: os['uptime'] ?? '',
      cpuBrand: cpu['brand'] ?? '未知 CPU',
      cpuCores: (cpu['cores'] ?? 0) is int
          ? cpu['cores']
          : int.tryParse('${cpu['cores']}') ?? 0,
      cpuPercent: _toDouble(metricsCpu['percentTotal']),
      memPercent: _toDouble(metricsMem['percentTotal']),
      memTotalBytes: _toInt(metricsMem['total']),
      memUsedBytes: _toInt(metricsMem['used']),
      arrayState: array['state'] ?? 'UNKNOWN',
      disks: disksJson
          .map((d) => ArrayDiskInfo.fromJson(d as Map<String, dynamic>))
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

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 GB';
    const gb = 1024 * 1024 * 1024;
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
}

class ArrayDiskInfo {
  final String name;
  final String status;
  final int? tempC;
  final String type;

  ArrayDiskInfo({
    required this.name,
    required this.status,
    required this.tempC,
    required this.type,
  });

  factory ArrayDiskInfo.fromJson(Map<String, dynamic> json) {
    return ArrayDiskInfo(
      name: json['name'] ?? '未知磁盘',
      status: json['status'] ?? 'DISK_NP',
      tempC: json['temp'] is int ? json['temp'] : null,
      type: json['type'] ?? 'DATA',
    );
  }

  bool get isHealthy => status == 'DISK_OK';
}
