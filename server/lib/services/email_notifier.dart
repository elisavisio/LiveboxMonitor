import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../models/server_models.dart';

typedef EmailSenderFn = Future<void> Function(Message message, SmtpServer server);

/// Sends SMTP email alerts whenever a new unknown device joins the Livebox LAN.
class EmailNotifier {
  final EmailSenderFn _sender;

  EmailNotifier({EmailSenderFn? sender}) : _sender = sender ?? send;

  SmtpServer _buildServer(SmtpConfig cfg) => SmtpServer(
        cfg.host,
        port: cfg.port,
        ssl: cfg.useSsl,
        allowInsecure: cfg.allowInsecure,
        ignoreBadCertificate: cfg.allowInsecure,
        username: cfg.username.isEmpty ? null : cfg.username,
        password: cfg.password.isEmpty ? null : cfg.password,
      );

  Future<bool> notifyNewDevice({
    required SmtpConfig config,
    required ServerDevice device,
    String? dashboardUrl,
  }) async {
    if (!config.enabled || config.host.trim().isEmpty) return false;
    final recipients = config.recipientList;
    if (recipients.isEmpty) return false;

    final fromAddr = config.fromAddress.trim().isNotEmpty
        ? config.fromAddress.trim()
        : (config.username.contains('@') ? config.username : 'livebox-monitor@local');

    final discoveredAt =
        DateTime.fromMillisecondsSinceEpoch(device.firstSeenMs).toLocal().toIso8601String();
    final linkLabel = device.isWifi ? 'Wi-Fi (${device.interfaceName})' : 'Ethernet (${device.interfaceName})';

    final msg = Message()
      ..from = Address(fromAddr, 'Livebox Monitor')
      ..recipients.addAll(recipients)
      ..subject = '[Livebox Monitor] Nouvel équipement détecté : ${device.name} (${device.mac})'
      ..text = '''
Un nouvel équipement vient d'apparaître sur votre réseau Livebox (marqué comme INCONNU) :

- Nom        : ${device.name}
- Adresse MAC: ${device.mac}
- Adresse IP : ${device.ipAddress.isNotEmpty ? device.ipAddress : 'En attente DHCP'}
- Fabricant  : ${device.vendor.isNotEmpty ? device.vendor : 'Inconnu'}
- Type       : ${device.deviceType}
- Connexion  : $linkLabel
- Date       : $discoveredAt
${dashboardUrl != null ? '\nOuvrir l\'interface web pour le marquer comme Connu : $dashboardUrl\n' : ''}
'''
      ..html = '''
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 560px; margin: 0 auto; background: #141822; color: #f1f5f9; border-radius: 12px; padding: 24px; border: 1px solid #283144;">
  <div style="display:flex; align-items:center; gap:10px; margin-bottom:16px;">
    <span style="display:inline-block; background:#FF7900; color:#fff; font-weight:700; padding:4px 10px; border-radius:999px; font-size:12px;">NOUVEL ÉQUIPEMENT</span>
    <span style="color:#94a3b8; font-size:12px;">Statut : INCONNU</span>
  </div>
  <h2 style="margin:0 0 12px 0; font-size:18px; color:#ffffff;">${_esc(device.name)}</h2>
  <table style="width:100%; border-collapse:collapse; font-size:13px;">
    <tr><td style="padding:6px 0; color:#94a3b8;">Adresse MAC</td><td style="padding:6px 0; font-family:monospace;">${_esc(device.mac)}</td></tr>
    <tr><td style="padding:6px 0; color:#94a3b8;">Adresse IP</td><td style="padding:6px 0; font-family:monospace;">${_esc(device.ipAddress.isNotEmpty ? device.ipAddress : 'En attente')}</td></tr>
    <tr><td style="padding:6px 0; color:#94a3b8;">Fabricant</td><td style="padding:6px 0;">${_esc(device.vendor.isNotEmpty ? device.vendor : 'Inconnu')}</td></tr>
    <tr><td style="padding:6px 0; color:#94a3b8;">Connexion</td><td style="padding:6px 0;">${_esc(linkLabel)}</td></tr>
    <tr><td style="padding:6px 0; color:#94a3b8;">Détecté le</td><td style="padding:6px 0; font-family:monospace;">${_esc(discoveredAt)}</td></tr>
  </table>
  ${dashboardUrl != null ? '<p style="margin-top:18px;"><a href="${_esc(dashboardUrl)}" style="background:#FF7900; color:#fff; text-decoration:none; padding:10px 16px; border-radius:8px; font-weight:600; display:inline-block;">Gérer cet équipement</a></p>' : ''}
</div>
''';

    await _sender(msg, _buildServer(config));
    return true;
  }

  Future<void> sendTestEmail(SmtpConfig config) async {
    if (config.host.trim().isEmpty) {
      throw ArgumentError('SMTP host is required');
    }
    final recipients = config.recipientList;
    if (recipients.isEmpty) {
      throw ArgumentError('At least one valid recipient email is required');
    }
    final fromAddr = config.fromAddress.trim().isNotEmpty
        ? config.fromAddress.trim()
        : (config.username.contains('@') ? config.username : 'livebox-monitor@local');

    final msg = Message()
      ..from = Address(fromAddr, 'Livebox Monitor')
      ..recipients.addAll(recipients)
      ..subject = '[Livebox Monitor] Test de notification SMTP réussi'
      ..text =
          'Votre serveur Livebox Monitor (Dart Frog) est bien configuré pour envoyer des alertes par email lorsqu\'un nouvel équipement apparaît sur le réseau.';

    await _sender(msg, _buildServer(config));
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
