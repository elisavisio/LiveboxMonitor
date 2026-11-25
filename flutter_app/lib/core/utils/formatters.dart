import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String bytes(num bytes) {
    if (bytes < 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double val = bytes.toDouble();
    int unit = 0;
    while (val >= 1024 && unit < units.length - 1) {
      val /= 1024;
      unit++;
    }
    return '${val.toStringAsFixed(unit == 0 ? 0 : 2)} ${units[unit]}';
  }

  /// Formats bits per second (e.g. throughput) cleanly.
  static String bitsPerSec(double bps) {
    if (bps <= 0) return '0 bps';
    const units = ['bps', 'Kbps', 'Mbps', 'Gbps'];
    double val = bps;
    int unit = 0;
    while (val >= 1000 && unit < units.length - 1) {
      val /= 1000;
      unit++;
    }
    return '${val.toStringAsFixed(val >= 100 ? 0 : 1)} ${units[unit]}';
  }

  /// Formats bytes per second as Mbps / Kbps.
  static String bytesPerSecAsBitrate(double bytesPerSec) =>
      bitsPerSec(bytesPerSec * 8.0);

  /// Formats seconds into human-readable uptime (e.g. `14d 06h 23m`).
  static String duration(int seconds) {
    if (seconds <= 0) return '0m';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (d > 0) return '${d}d ${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String timeHms(DateTime dt) => DateFormat('HH:mm:ss').format(dt);

  static String dateTime(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

  static String dateShort(DateTime dt) => DateFormat('dd/MM HH:mm').format(dt);

  static IconData deviceTypeIcon(String deviceType) {
    final t = deviceType.toLowerCase();
    if (t.contains('mobile') || t.contains('smartphone')) return Icons.smartphone_rounded;
    if (t.contains('tablet')) return Icons.tablet_mac_rounded;
    if (t.contains('laptop') || t.contains('notebook')) return Icons.laptop_mac_rounded;
    if (t.contains('desktop') || t.contains('computer')) return Icons.desktop_windows_rounded;
    if (t.contains('tv') || t.contains('set-top') || t.contains('chromecast') || t.contains('apple tv')) {
      return Icons.tv_rounded;
    }
    if (t.contains('console')) return Icons.sports_esports_rounded;
    if (t.contains('printer')) return Icons.print_rounded;
    if (t.contains('camera')) return Icons.videocam_rounded;
    if (t.contains('nas') || t.contains('disk') || t.contains('storage') || t.contains('usb')) {
      return Icons.storage_rounded;
    }
    if (t.contains('repeater') || t.contains('acces') || t.contains('access') || t.contains('extender') || t.contains('sah ap') || t.contains('repeteur')) {
      return Icons.wifi_tethering_rounded;
    }
    if (t.contains('switch')) return Icons.hub_rounded;
    if (t.contains('bulb') || t.contains('light')) return Icons.lightbulb_outline_rounded;
    if (t.contains('plug') || t.contains('outlet') || t.contains('power')) return Icons.power_rounded;
    if (t.contains('phone')) return Icons.phone_rounded;
    if (t.contains('hifi') || t.contains('speaker') || t.contains('radio')) return Icons.speaker_rounded;
    if (t.contains('sensor') || t.contains('detector')) return Icons.sensors_rounded;
    return Icons.devices_other_rounded;
  }

  /// Returns 0..4 signal quality bars from RSSI dBm.
  static int rssiBars(int? rssi) {
    if (rssi == null || rssi == 0) return 0;
    if (rssi >= -55) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }
}
