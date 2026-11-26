import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../models/server_models.dart';

/// Lightweight, durable, encrypted credential store using AES-256-GCM.
///
/// Key sourcing priority:
/// 1. Docker Secret file (`LBM_MASTER_KEY_FILE` or `/run/secrets/lbm_master_key`)
/// 2. Environment variable (`LBM_MASTER_KEY`)
/// 3. Auto-generated 256-bit key persisted with `chmod 600` at `<dataDir>/.master.key`
///
/// Secrets are encrypted with a fresh 96-bit random nonce on every write and
/// stored atomically in `<dataDir>/secrets.enc.json` (`chmod 600`).
class SecretVault {
  final String dataDir;
  final String? explicitKey;

  final AesGcm _aesGcm = AesGcm.with256bits();
  SecretKey? _secretKey;
  String _keySource = 'uninitialized';

  SecretVault({required this.dataDir, this.explicitKey});

  String get vaultPath => p.join(dataDir, 'secrets.enc.json');
  String get keyFilePath => p.join(dataDir, '.master.key');
  String get keySource => _keySource;

  Future<void> initialize() async {
    await Directory(dataDir).create(recursive: true);
    final rawKeyMaterial = await _resolveMasterKeyMaterial();
    final hash = await Sha256().hash(utf8.encode(rawKeyMaterial));
    _secretKey = SecretKey(hash.bytes);
  }

  Future<String> _resolveMasterKeyMaterial() async {
    if (explicitKey != null && explicitKey!.isNotEmpty) {
      _keySource = 'explicit';
      return explicitKey!;
    }

    final secretFileEnv = Platform.environment['LBM_MASTER_KEY_FILE'] ??
        '/run/secrets/lbm_master_key';
    final dockerSecretFile = File(secretFileEnv);
    if (dockerSecretFile.existsSync()) {
      final text = dockerSecretFile.readAsStringSync().trim();
      if (text.isNotEmpty) {
        _keySource = 'docker_secret';
        return text;
      }
    }

    final envKey = Platform.environment['LBM_MASTER_KEY']?.trim();
    if (envKey != null && envKey.isNotEmpty) {
      _keySource = 'env_var';
      return envKey;
    }

    final localKeyFile = File(keyFilePath);
    if (localKeyFile.existsSync()) {
      final existing = localKeyFile.readAsStringSync().trim();
      if (existing.isNotEmpty) {
        _keySource = 'volume_keyfile';
        return existing;
      }
    }

    // Generate cryptographically secure 32-byte key on first boot
    final rng = Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
    final generated = base64Url.encode(bytes);
    await localKeyFile.writeAsString('$generated\n', flush: true);
    await _chmod600(localKeyFile.path);
    _keySource = 'volume_keyfile';
    return generated;
  }

  Future<void> _chmod600(String filePath) async {
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', filePath]);
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _readAll() async {
    if (_secretKey == null) await initialize();
    final file = File(vaultPath);
    if (!file.existsSync()) return <String, dynamic>{};

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return <String, dynamic>{};

    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final nonce = base64Decode(envelope['nonce'] as String);
    final cipherText = base64Decode(envelope['cipher'] as String);
    final macBytes = base64Decode(envelope['mac'] as String);

    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final clearBytes = await _aesGcm.decrypt(box, secretKey: _secretKey!);
    final decoded = jsonDecode(utf8.decode(clearBytes));
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<void> _writeAll(Map<String, dynamic> payload) async {
    if (_secretKey == null) await initialize();
    final clearBytes = utf8.encode(jsonEncode(payload));
    final nonce = _aesGcm.newNonce();
    final box = await _aesGcm.encrypt(
      clearBytes,
      secretKey: _secretKey!,
      nonce: nonce,
    );

    final envelope = {
      'v': 1,
      'alg': 'AES-256-GCM',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };

    final tmp = File('$vaultPath.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(envelope), flush: true);
    await _chmod600(tmp.path);
    await tmp.rename(vaultPath);
    await _chmod600(vaultPath);
  }

  Future<LiveboxCredentials?> loadLiveboxCredentials() async {
    final all = await _readAll();
    final raw = all['livebox'];
    if (raw is Map<String, dynamic>) {
      return LiveboxCredentials.fromJson(raw);
    }
    return null;
  }

  Future<void> saveLiveboxCredentials(LiveboxCredentials creds) async {
    final all = await _readAll();
    all['livebox'] = creds.toJson();
    await _writeAll(all);
  }

  Future<SmtpConfig> loadSmtpConfig() async {
    final all = await _readAll();
    final raw = all['smtp'];
    if (raw is Map<String, dynamic>) {
      return SmtpConfig.fromJson(raw);
    }
    return const SmtpConfig();
  }

  Future<void> saveSmtpConfig(SmtpConfig config) async {
    final all = await _readAll();
    all['smtp'] = config.toJson();
    await _writeAll(all);
  }
}
