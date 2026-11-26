import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart';

import '../models/server_models.dart';

/// Persistent, lightweight SQLite storage for Livebox devices, known/unknown
/// tags, presence history, per-device bandwidth time-series, and event log.
class MonitorDatabase {
  final Database _db;
  static bool _loaderConfigured = false;

  MonitorDatabase._(this._db);

  static void _ensureLinuxSqliteLoader() {
    if (_loaderConfigured || !Platform.isLinux) return;
    _loaderConfigured = true;
    sqlite_open.open.overrideFor(sqlite_open.OperatingSystem.linux, () {
      for (final candidate in const [
        'libsqlite3.so.0',
        'libsqlite3.so',
        '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
        '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
      ]) {
        try {
          return DynamicLibrary.open(candidate);
        } catch (_) {}
      }
      return DynamicLibrary.open('libsqlite3.so');
    });
  }

  static MonitorDatabase open({required String dataDir}) {
    _ensureLinuxSqliteLoader();
    Directory(dataDir).createSync(recursive: true);
    final dbPath = p.join(dataDir, 'livebox_monitor.db');
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA synchronous = NORMAL;');
    final instance = MonitorDatabase._(db);
    instance._migrate();
    return instance;
  }

  static MonitorDatabase openInMemory() {
    _ensureLinuxSqliteLoader();
    final db = sqlite3.openInMemory();
    final instance = MonitorDatabase._(db);
    instance._migrate();
    return instance;
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS devices (
        mac TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        vendor TEXT NOT NULL DEFAULT '',
        device_type TEXT NOT NULL DEFAULT 'Unknown',
        ip_address TEXT NOT NULL DEFAULT '',
        ipv6_address TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 0,
        link_type TEXT NOT NULL DEFAULT 'eth',
        interface_name TEXT NOT NULL DEFAULT '',
        parent_node_id TEXT NOT NULL DEFAULT 'LIVEBOX',
        rssi INTEGER,
        link_speed_mbps INTEGER,
        rx_bytes INTEGER NOT NULL DEFAULT 0,
        tx_bytes INTEGER NOT NULL DEFAULT 0,
        rx_bps REAL NOT NULL DEFAULT 0,
        tx_bps REAL NOT NULL DEFAULT 0,
        trust TEXT NOT NULL DEFAULT 'unknown',
        first_seen_ms INTEGER NOT NULL,
        last_seen_ms INTEGER NOT NULL,
        last_changed_ms INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS presence_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mac TEXT NOT NULL,
        ts_ms INTEGER NOT NULL,
        online INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_presence_mac_ts
        ON presence_history(mac, ts_ms);

      CREATE TABLE IF NOT EXISTS bandwidth_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mac TEXT NOT NULL,
        ts_ms INTEGER NOT NULL,
        rx_bps REAL NOT NULL,
        tx_bps REAL NOT NULL,
        rx_bytes INTEGER NOT NULL,
        tx_bytes INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_bw_mac_ts
        ON bandwidth_samples(mac, ts_ms);

      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_ms INTEGER NOT NULL,
        mac TEXT NOT NULL,
        device_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        summary TEXT NOT NULL,
        raw_json TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts_ms DESC);
    ''');
  }

  void close() => _db.dispose();

  ServerDevice _rowToDevice(Row r) => ServerDevice(
        mac: r['mac'] as String,
        name: r['name'] as String,
        note: (r['note'] as String?) ?? '',
        vendor: (r['vendor'] as String?) ?? '',
        deviceType: (r['device_type'] as String?) ?? 'Unknown',
        ipAddress: (r['ip_address'] as String?) ?? '',
        ipv6Address: (r['ipv6_address'] as String?) ?? '',
        active: (r['active'] as int) == 1,
        linkType: (r['link_type'] as String?) ?? 'eth',
        interfaceName: (r['interface_name'] as String?) ?? '',
        parentNodeId: (r['parent_node_id'] as String?) ?? 'LIVEBOX',
        rssi: r['rssi'] as int?,
        linkSpeedMbps: r['link_speed_mbps'] as int?,
        rxBytes: (r['rx_bytes'] as int?) ?? 0,
        txBytes: (r['tx_bytes'] as int?) ?? 0,
        rxBytesPerSec: (r['rx_bps'] as num?)?.toDouble() ?? 0.0,
        txBytesPerSec: (r['tx_bps'] as num?)?.toDouble() ?? 0.0,
        trust: DeviceTrust.fromString(r['trust'] as String?),
        firstSeenMs: r['first_seen_ms'] as int,
        lastSeenMs: r['last_seen_ms'] as int,
        lastChangedMs: r['last_changed_ms'] as int,
      );

  ServerDevice? getDevice(String mac) {
    final norm = mac.toUpperCase();
    final res = _db.select('SELECT * FROM devices WHERE mac = ?', [norm]);
    if (res.isEmpty) return null;
    return _rowToDevice(res.first);
  }

  List<ServerDevice> listDevices() {
    final res = _db.select('SELECT * FROM devices ORDER BY active DESC, name COLLATE NOCASE ASC');
    return res.map(_rowToDevice).toList();
  }

  /// Inserts or updates a device while preserving user-assigned `trust` and `note`.
  /// Returns `isNew = true` if this MAC was never seen before in the database.
  ({ServerDevice device, bool isNew, bool presenceChanged}) upsertDevice(
    ServerDevice incoming, {
    int? nowMs,
  }) {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final mac = incoming.mac.toUpperCase();
    final existing = getDevice(mac);

    if (existing == null) {
      final created = ServerDevice(
        mac: mac,
        name: incoming.name.isNotEmpty ? incoming.name : mac,
        note: incoming.note,
        vendor: incoming.vendor,
        deviceType: incoming.deviceType,
        ipAddress: incoming.ipAddress,
        ipv6Address: incoming.ipv6Address,
        active: incoming.active,
        linkType: incoming.linkType,
        interfaceName: incoming.interfaceName,
        parentNodeId: incoming.parentNodeId,
        rssi: incoming.rssi,
        linkSpeedMbps: incoming.linkSpeedMbps,
        rxBytes: incoming.rxBytes,
        txBytes: incoming.txBytes,
        rxBytesPerSec: incoming.rxBytesPerSec,
        txBytesPerSec: incoming.txBytesPerSec,
        trust: incoming.trust,
        firstSeenMs: incoming.firstSeenMs > 0 ? incoming.firstSeenMs : ts,
        lastSeenMs: ts,
        lastChangedMs: ts,
      );

      _db.execute(
        '''
        INSERT INTO devices (
          mac, name, note, vendor, device_type, ip_address, ipv6_address,
          active, link_type, interface_name, parent_node_id, rssi, link_speed_mbps,
          rx_bytes, tx_bytes, rx_bps, tx_bps, trust, first_seen_ms, last_seen_ms, last_changed_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          created.mac,
          created.name,
          created.note,
          created.vendor,
          created.deviceType,
          created.ipAddress,
          created.ipv6Address,
          created.active ? 1 : 0,
          created.linkType,
          created.interfaceName,
          created.parentNodeId,
          created.rssi,
          created.linkSpeedMbps,
          created.rxBytes,
          created.txBytes,
          created.rxBytesPerSec,
          created.txBytesPerSec,
          created.trust.name,
          created.firstSeenMs,
          created.lastSeenMs,
          created.lastChangedMs,
        ],
      );
      recordPresence(mac, created.active, ts);
      return (device: created, isNew: true, presenceChanged: true);
    }

    final presenceChanged = existing.active != incoming.active;
    final merged = existing.copyWith(
      name: incoming.name.isNotEmpty ? incoming.name : existing.name,
      vendor: incoming.vendor.isNotEmpty ? incoming.vendor : existing.vendor,
      deviceType: incoming.deviceType != 'Unknown' ? incoming.deviceType : existing.deviceType,
      ipAddress: incoming.ipAddress.isNotEmpty ? incoming.ipAddress : existing.ipAddress,
      ipv6Address: incoming.ipv6Address.isNotEmpty ? incoming.ipv6Address : existing.ipv6Address,
      active: incoming.active,
      linkType: incoming.linkType.isNotEmpty ? incoming.linkType : existing.linkType,
      interfaceName:
          incoming.interfaceName.isNotEmpty ? incoming.interfaceName : existing.interfaceName,
      parentNodeId:
          incoming.parentNodeId.isNotEmpty ? incoming.parentNodeId : existing.parentNodeId,
      rssi: incoming.rssi ?? existing.rssi,
      linkSpeedMbps: incoming.linkSpeedMbps ?? existing.linkSpeedMbps,
      rxBytes: incoming.rxBytes > 0 ? incoming.rxBytes : existing.rxBytes,
      txBytes: incoming.txBytes > 0 ? incoming.txBytes : existing.txBytes,
      rxBytesPerSec: incoming.rxBytesPerSec,
      txBytesPerSec: incoming.txBytesPerSec,
      lastSeenMs: incoming.active ? ts : existing.lastSeenMs,
      lastChangedMs: presenceChanged ? ts : existing.lastChangedMs,
    );

    _db.execute(
      '''
      UPDATE devices SET
        name = ?, vendor = ?, device_type = ?, ip_address = ?, ipv6_address = ?,
        active = ?, link_type = ?, interface_name = ?, parent_node_id = ?,
        rssi = ?, link_speed_mbps = ?, rx_bytes = ?, tx_bytes = ?,
        rx_bps = ?, tx_bps = ?, last_seen_ms = ?, last_changed_ms = ?
      WHERE mac = ?
      ''',
      [
        merged.name,
        merged.vendor,
        merged.deviceType,
        merged.ipAddress,
        merged.ipv6Address,
        merged.active ? 1 : 0,
        merged.linkType,
        merged.interfaceName,
        merged.parentNodeId,
        merged.rssi,
        merged.linkSpeedMbps,
        merged.rxBytes,
        merged.txBytes,
        merged.rxBytesPerSec,
        merged.txBytesPerSec,
        merged.lastSeenMs,
        merged.lastChangedMs,
        mac,
      ],
    );

    if (presenceChanged) {
      recordPresence(mac, merged.active, ts);
    }

    return (device: merged, isNew: false, presenceChanged: presenceChanged);
  }

  ServerDevice? setDeviceTrust(String mac, DeviceTrust trust, {String? note}) {
    final norm = mac.toUpperCase();
    final existing = getDevice(norm);
    if (existing == null) return null;
    final newNote = note ?? existing.note;
    _db.execute(
      'UPDATE devices SET trust = ?, note = ? WHERE mac = ?',
      [trust.name, newNote, norm],
    );
    return getDevice(norm);
  }

  void updateDeviceBandwidth({
    required String mac,
    required int rxBytes,
    required int txBytes,
    required double rxBytesPerSec,
    required double txBytesPerSec,
    int? tsMs,
  }) {
    final norm = mac.toUpperCase();
    final ts = tsMs ?? DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      UPDATE devices
      SET rx_bytes = CASE WHEN ? > rx_bytes THEN ? ELSE rx_bytes END,
          tx_bytes = CASE WHEN ? > tx_bytes THEN ? ELSE tx_bytes END,
          rx_bps = ?, tx_bps = ?, last_seen_ms = ?
      WHERE mac = ?
      ''',
      [rxBytes, rxBytes, txBytes, txBytes, rxBytesPerSec, txBytesPerSec, ts, norm],
    );
    _db.execute(
      '''
      INSERT INTO bandwidth_samples (mac, ts_ms, rx_bps, tx_bps, rx_bytes, tx_bytes)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [norm, ts, rxBytesPerSec, txBytesPerSec, rxBytes, txBytes],
    );
  }

  void recordPresence(String mac, bool online, int tsMs) {
    _db.execute(
      'INSERT INTO presence_history (mac, ts_ms, online) VALUES (?, ?, ?)',
      [mac.toUpperCase(), tsMs, online ? 1 : 0],
    );
  }

  /// Computes continuous [PresenceSpan] intervals across `[sinceMs, nowMs]` plus uptime ratio.
  ({List<PresenceSpan> spans, double uptimePercent}) getPresenceTimeline(
    String mac, {
    required int sinceMs,
    int? untilMs,
  }) {
    final norm = mac.toUpperCase();
    final endMs = untilMs ?? DateTime.now().millisecondsSinceEpoch;
    final dev = getDevice(norm);

    // State immediately prior to `sinceMs`
    final prior = _db.select(
      'SELECT online FROM presence_history WHERE mac = ? AND ts_ms <= ? ORDER BY ts_ms DESC LIMIT 1',
      [norm, sinceMs],
    );
    bool currentOnline = prior.isNotEmpty
        ? (prior.first['online'] as int) == 1
        : (dev?.active ?? false);

    final rows = _db.select(
      'SELECT ts_ms, online FROM presence_history WHERE mac = ? AND ts_ms > ? AND ts_ms <= ? ORDER BY ts_ms ASC',
      [norm, sinceMs, endMs],
    );

    final spans = <PresenceSpan>[];
    int cursor = sinceMs;
    int onlineDurationMs = 0;

    for (final r in rows) {
      final ts = r['ts_ms'] as int;
      final nextOnline = (r['online'] as int) == 1;
      if (ts > cursor) {
        spans.add(PresenceSpan(startMs: cursor, endMs: ts, online: currentOnline));
        if (currentOnline) onlineDurationMs += ts - cursor;
        cursor = ts;
      }
      currentOnline = nextOnline;
    }

    if (endMs > cursor) {
      spans.add(PresenceSpan(startMs: cursor, endMs: endMs, online: currentOnline));
      if (currentOnline) onlineDurationMs += endMs - cursor;
    }

    final totalMs = (endMs - sinceMs).clamp(1, 1 << 62);
    final pct = (onlineDurationMs / totalMs) * 100.0;
    return (spans: spans, uptimePercent: pct);
  }

  List<BandwidthPoint> getBandwidthHistory(
    String mac, {
    required int sinceMs,
    int maxPoints = 240,
  }) {
    final norm = mac.toUpperCase();
    final rows = _db.select(
      '''
      SELECT ts_ms, rx_bps, tx_bps, rx_bytes, tx_bytes
      FROM bandwidth_samples
      WHERE mac = ? AND ts_ms >= ?
      ORDER BY ts_ms ASC
      ''',
      [norm, sinceMs],
    );
    final all = rows
        .map((r) => BandwidthPoint(
              timestampMs: r['ts_ms'] as int,
              rxBytesPerSec: (r['rx_bps'] as num).toDouble(),
              txBytesPerSec: (r['tx_bps'] as num).toDouble(),
              rxBytes: r['rx_bytes'] as int,
              txBytes: r['tx_bytes'] as int,
            ))
        .toList();

    if (all.length <= maxPoints) return all;
    // Downsample evenly while preserving peaks
    final step = all.length / maxPoints;
    final out = <BandwidthPoint>[];
    for (int i = 0; i < maxPoints; i++) {
      final idx = (i * step).floor().clamp(0, all.length - 1);
      out.add(all[idx]);
    }
    return out;
  }

  MonitorEvent insertEvent({
    required String deviceMac,
    required String deviceName,
    required String reason,
    required String summary,
    required String rawJson,
    int? tsMs,
  }) {
    final ts = tsMs ?? DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''
      INSERT INTO events (ts_ms, mac, device_name, reason, summary, raw_json)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [ts, deviceMac.toUpperCase(), deviceName, reason, summary, rawJson],
    );
    final id = _db.lastInsertRowId;
    return MonitorEvent(
      id: id,
      timestampMs: ts,
      deviceMac: deviceMac.toUpperCase(),
      deviceName: deviceName,
      reason: reason,
      summary: summary,
      rawJson: rawJson,
    );
  }

  List<MonitorEvent> listEvents({int limit = 150, String? mac}) {
    final rows = mac != null && mac.isNotEmpty
        ? _db.select(
            'SELECT * FROM events WHERE mac = ? ORDER BY ts_ms DESC LIMIT ?',
            [mac.toUpperCase(), limit],
          )
        : _db.select(
            'SELECT * FROM events ORDER BY ts_ms DESC LIMIT ?',
            [limit],
          );
    return rows
        .map((r) => MonitorEvent(
              id: r['id'] as int,
              timestampMs: r['ts_ms'] as int,
              deviceMac: r['mac'] as String,
              deviceName: r['device_name'] as String,
              reason: r['reason'] as String,
              summary: r['summary'] as String,
              rawJson: r['raw_json'] as String,
            ))
        .toList();
  }

  /// Keeps SQLite compact by pruning samples older than [retentionDays].
  void pruneOldHistory({int retentionDays = 7}) {
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    _db.execute('DELETE FROM bandwidth_samples WHERE ts_ms < ?', [cutoff]);
    _db.execute(
      'DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY ts_ms DESC LIMIT 5000)',
    );
  }

  /// Removes demo/simulated device records (e.g. left over from an earlier run
  /// in Demo Mode) from all tables while preserving real Livebox devices.
  int purgeDemoArtifacts(List<String> demoMacs, {String? simulatedPrefix}) {
    int removed = 0;
    for (final rawMac in demoMacs) {
      final mac = rawMac.toUpperCase();
      final existed = getDevice(mac) != null;
      _db.execute('DELETE FROM devices WHERE mac = ?', [mac]);
      _db.execute('DELETE FROM presence_history WHERE mac = ?', [mac]);
      _db.execute('DELETE FROM bandwidth_samples WHERE mac = ?', [mac]);
      _db.execute('DELETE FROM events WHERE mac = ?', [mac]);
      if (existed) removed++;
    }
    if (simulatedPrefix != null && simulatedPrefix.isNotEmpty) {
      final pattern = '${simulatedPrefix.toUpperCase()}%';
      final rows = _db.select(
        'SELECT mac FROM devices WHERE mac LIKE ?',
        [pattern],
      );
      removed += rows.length;
      _db.execute('DELETE FROM devices WHERE mac LIKE ?', [pattern]);
      _db.execute('DELETE FROM presence_history WHERE mac LIKE ?', [pattern]);
      _db.execute('DELETE FROM bandwidth_samples WHERE mac LIKE ?', [pattern]);
      _db.execute('DELETE FROM events WHERE mac LIKE ?', [pattern]);
    }
    return removed;
  }
}
