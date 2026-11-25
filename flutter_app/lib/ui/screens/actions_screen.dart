import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class ActionsScreen extends StatefulWidget {
  final AppController controller;
  const ActionsScreen({super.key, required this.controller});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  bool _runningSpeedTest = false;
  final _serviceCtrl = TextEditingController(text: 'DeviceInfo');
  final _methodCtrl = TextEditingController(text: 'get');
  final _paramsCtrl = TextEditingController(text: '{}');
  String _apiResponse = '';
  bool _callingApi = false;

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _methodCtrl.dispose();
    _paramsCtrl.dispose();
    super.dispose();
  }

  Future<void> _runRawApi() async {
    setState(() => _callingApi = true);
    try {
      final rawParams = _paramsCtrl.text.trim().isEmpty ? '{}' : _paramsCtrl.text.trim();
      final decoded = jsonDecode(rawParams);
      final params = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final out = await widget.controller.executeRawApi(
        _serviceCtrl.text.trim(),
        _methodCtrl.text.trim(),
        params,
      );
      setState(() => _apiResponse = out);
    } catch (e) {
      setState(() => _apiResponse = 'Error: $e');
    } finally {
      setState(() => _callingApi = false);
    }
  }

  Future<void> _showEditWifiBandDialog(WifiBandConfig band) async {
    final s = widget.controller.strings;
    final ssidCtrl = TextEditingController(text: band.ssid);
    bool broadcast = band.broadcastSsid;
    bool enabled = band.enabled;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Wi-Fi ${band.band}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.enabled),
                  value: enabled,
                  onChanged: (v) => setLocal(() => enabled = v),
                ),
                TextField(
                  controller: ssidCtrl,
                  decoration: const InputDecoration(labelText: 'SSID'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('Broadcast SSID', 'Diffuser le SSID')),
                  value: broadcast,
                  onChanged: (v) => setLocal(() => broadcast = v),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.save)),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.controller.saveWifiBand(
        band.copyWith(enabled: enabled, ssid: ssidCtrl.text.trim(), broadcastSsid: broadcast),
      );
    }
  }

  Future<void> _showAddDynDnsDialog() async {
    final s = widget.controller.strings;
    String service = 'no-ip';
    final hostCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.t('Add DynDNS Host', 'Ajouter un hôte DynDNS')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: service,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: const [
                    DropdownMenuItem(value: 'no-ip', child: Text('No-IP')),
                    DropdownMenuItem(value: 'dyndns', child: Text('DynDNS')),
                    DropdownMenuItem(value: 'dtdns', child: Text('DtDNS')),
                  ],
                  onChanged: (v) => setLocal(() => service = v ?? 'no-ip'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hostCtrl,
                  decoration: const InputDecoration(labelText: 'Hostname', hintText: 'home.ddns.net'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(labelText: s.t('Username', 'Utilisateur')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.t('Password', 'Mot de passe')),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
          ],
        ),
      ),
    );

    if (ok == true && hostCtrl.text.trim().isNotEmpty) {
      await widget.controller.addDynDnsHost(
        service,
        hostCtrl.text.trim(),
        userCtrl.text.trim(),
        passCtrl.text,
      );
    }
  }

  Future<void> _showAddRouteDialog() async {
    final s = widget.controller.strings;
    final dstCtrl = TextEditingController(text: '10.30.0.0/24');
    final gwCtrl = TextEditingController(text: '192.168.1.');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Add Static IPv4 Route', 'Ajouter une route statique IPv4')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dstCtrl,
                decoration: const InputDecoration(labelText: 'Destination CIDR (e.g. 10.30.0.0/24)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gwCtrl,
                decoration: InputDecoration(labelText: s.t('Gateway IP', 'Passerelle')),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
        ],
      ),
    );
    if (ok == true && dstCtrl.text.trim().isNotEmpty && gwCtrl.text.trim().isNotEmpty) {
      await widget.controller.addStaticRoute(dstCtrl.text.trim(), gwCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final info = c.info;
    if (info == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Wi-Fi Controls + Speed Test / AutoDiag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SectionCard(
                  title: s.t('Wi-Fi Radios & Scheduler', 'Réseaux Wi-Fi & Planificateur'),
                  icon: Icons.wifi_rounded,
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.t('Global Wi-Fi', 'Wi-Fi Global'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        value: info.wifiEnabled,
                        onChanged: c.setGlobalWifi,
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.t('Guest Wi-Fi (4h timer)', 'Wi-Fi Invité (minuteur 4h)'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        value: info.guestWifiEnabled,
                        onChanged: (v) => c.setGuestWifi(v, timerHours: v ? 4 : 0),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.t('Wi-Fi Scheduler', 'Planificateur Wi-Fi'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        value: info.wifiSchedulerEnabled,
                        onChanged: c.setWifiScheduler,
                      ),
                      Divider(height: 18, color: context.borderColor),
                      ...c.wifiBands.map((b) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.wifi_rounded,
                              size: 18,
                              color: b.enabled ? AppColors.orange : context.textSecondary,
                            ),
                            title: Text('${b.band} · ${b.ssid}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text('${b.securityMode} · Ch ${b.channel} · ${b.bandwidth}',
                                style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
                            trailing: OutlinedButton(
                              onPressed: () => _showEditWifiBandDialog(b),
                              child: Text(s.edit),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Speed Test + LEDs / Screen
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    SectionCard(
                      title: s.t('Livebox Speed Test', 'Test de débit Livebox'),
                      icon: Icons.speed_rounded,
                      iconColor: AppColors.info,
                      actions: [
                        FilledButton.icon(
                          onPressed: _runningSpeedTest
                              ? null
                              : () async {
                                  setState(() => _runningSpeedTest = true);
                                  await c.runSpeedTest();
                                  if (mounted) setState(() => _runningSpeedTest = false);
                                },
                          icon: _runningSpeedTest
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 16),
                          label: Text(_runningSpeedTest
                              ? s.t('Testing...', 'Test en cours...')
                              : s.t('Run Test', 'Lancer')),
                        ),
                      ],
                      child: c.lastSpeedTest == null
                          ? Text(
                              s.t(
                                'Run an AutoDiag WAN speed test directly on the Livebox fiber interface.',
                                'Lancez un test de débit WAN AutoDiag directement sur la Fibre Livebox.',
                              ),
                              style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _SpeedMetric(
                                  label: 'Download',
                                  value: '${c.lastSpeedTest!.downloadMbps.toStringAsFixed(0)} Mbps',
                                  color: AppColors.info,
                                ),
                                _SpeedMetric(
                                  label: 'Upload',
                                  value: '${c.lastSpeedTest!.uploadMbps.toStringAsFixed(0)} Mbps',
                                  color: AppColors.purple,
                                ),
                                _SpeedMetric(
                                  label: 'Ping',
                                  value: '${c.lastSpeedTest!.pingMs.toStringAsFixed(1)} ms',
                                  color: AppColors.success,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: s.t('LEDs & Front Display', 'LEDs & Écran Livebox'),
                      icon: Icons.light_mode_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(s.t('Orange LED Brightness', 'Luminosité LED Orange'),
                                  style: const TextStyle(fontSize: 13)),
                              const Spacer(),
                              Text('${((info.orangeLedLevel / 255) * 100).round()}%',
                                  style: AppTheme.monoStyle.copyWith(fontSize: 12)),
                            ],
                          ),
                          Slider(
                            value: info.orangeLedLevel.toDouble().clamp(0, 255),
                            min: 0,
                            max: 255,
                            activeColor: AppColors.orange,
                            onChanged: (v) => c.setLedBrightness(v.round()),
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              s.t('Show Wi-Fi Password on Screen', 'Afficher le mot de passe Wi-Fi'),
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: info.showWifiPasswordOnScreen,
                            onChanged: c.setShowWifiPasswordOnScreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: System (Reboot + Backup/Restore) + DynDNS + Static Routes
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reboot & Cloud Backup
              Expanded(
                child: SectionCard(
                  title: s.t('System, Reboot & Cloud Backup', 'Système, Redémarrage & Sauvegarde'),
                  icon: Icons.power_settings_new_rounded,
                  iconColor: AppColors.danger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: s.t('Reboot Livebox', 'Redémarrer la Livebox'),
                                message: s.t(
                                  'This will temporarily disconnect Internet, TV, and Phone for ~2 minutes.',
                                  'Cela coupera temporairement Internet, la TV et le téléphone (~2 minutes).',
                                ),
                                destructive: true,
                              );
                              if (ok) {
                                await c.rebootLivebox();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(s.t('Reboot command sent', 'Redémarrage lancé'))),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 16),
                            label: Text(s.t('Reboot Livebox', 'Redémarrer Livebox')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await c.triggerBackup();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(s.t('Cloud backup launched', 'Sauvegarde Cloud lancée'))),
                                );
                              }
                            },
                            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                            label: Text(s.t('Cloud Backup', 'Sauvegarde Cloud')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: s.t('Restore Cloud Backup', 'Restaurer la sauvegarde Cloud'),
                                message: s.t(
                                  'Restore last Orange Cloud config and reboot Livebox?',
                                  'Restaurer la dernière configuration Cloud et redémarrer ?',
                                ),
                                destructive: true,
                              );
                              if (ok) await c.triggerRestore();
                            },
                            icon: const Icon(Icons.cloud_download_outlined, size: 16),
                            label: Text(s.t('Restore', 'Restaurer')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(s.t('Recent Reboot History', 'Historique des redémarrages'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary)),
                      const SizedBox(height: 6),
                      ...c.rebootHistory.take(4).map((r) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history_rounded, size: 17, color: AppColors.warning),
                            title: Text(r.bootReason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${Formatters.dateTime(r.bootDate)} · ${r.shutdownReason}',
                              style: AppTheme.monoStyle.copyWith(fontSize: 11, color: context.textSecondary),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // DynDNS & Static Routes
              Expanded(
                child: Column(
                  children: [
                    SectionCard(
                      title: 'DynDNS',
                      icon: Icons.public_rounded,
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _showAddDynDnsDialog,
                          icon: const Icon(Icons.add_rounded, size: 15),
                          label: Text(s.add),
                        ),
                      ],
                      child: c.dynDnsHosts.isEmpty
                          ? Text(s.t('No DynDNS hosts configured.', 'Aucun hôte DynDNS.'),
                              style: TextStyle(color: context.textSecondary))
                          : Column(
                              children: c.dynDnsHosts
                                  .map((h) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(h.hostname,
                                            style: AppTheme.monoStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                                        subtitle: Text('${h.service} · ${h.username} · ${h.status}',
                                            style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              size: 17, color: AppColors.danger),
                                          onPressed: () => c.deleteDynDnsHost(h.hostname),
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: s.t('Static IPv4 Routes', 'Routes statiques IPv4'),
                      icon: Icons.fork_right_rounded,
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _showAddRouteDialog,
                          icon: const Icon(Icons.add_rounded, size: 15),
                          label: Text(s.add),
                        ),
                      ],
                      child: c.staticRoutes.isEmpty
                          ? Text(s.t('No static routes.', 'Aucune route statique.'),
                              style: TextStyle(color: context.textSecondary))
                          : Column(
                              children: c.staticRoutes
                                  .map((r) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('${r.destination}  →  ${r.gateway}',
                                            style: AppTheme.monoStyle.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                        subtitle: Text(r.interfaceName,
                                            style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              size: 17, color: AppColors.danger),
                                          onPressed: () => c.deleteStaticRoute(r.id),
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 3: Raw Sysbus API Explorer
          SectionCard(
            title: s.t('Sysbus API Explorer', 'Explorateur d\'API Sysbus'),
            subtitle: s.t(
              'Execute raw Livebox JSON-RPC calls directly (e.g. DeviceInfo:get, NMC:getWANStatus)',
              'Exécutez des appels JSON-RPC Livebox directement (ex: DeviceInfo:get, NMC:getWANStatus)',
            ),
            icon: Icons.terminal_rounded,
            iconColor: AppColors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('DeviceInfo:get'),
                      onPressed: () => setState(() {
                        _serviceCtrl.text = 'DeviceInfo';
                        _methodCtrl.text = 'get';
                        _paramsCtrl.text = '{}';
                      }),
                    ),
                    ActionChip(
                      label: const Text('NMC:getWANStatus'),
                      onPressed: () => setState(() {
                        _serviceCtrl.text = 'NMC';
                        _methodCtrl.text = 'getWANStatus';
                        _paramsCtrl.text = '{}';
                      }),
                    ),
                    ActionChip(
                      label: const Text('Time:getTime'),
                      onPressed: () => setState(() {
                        _serviceCtrl.text = 'Time';
                        _methodCtrl.text = 'getTime';
                        _paramsCtrl.text = '{}';
                      }),
                    ),
                    ActionChip(
                      label: const Text('HomeLan.Interface:get'),
                      onPressed: () => setState(() {
                        _serviceCtrl.text = 'HomeLan.Interface';
                        _methodCtrl.text = 'get';
                        _paramsCtrl.text = '{}';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _serviceCtrl,
                        decoration: const InputDecoration(labelText: 'Service'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _methodCtrl,
                        decoration: const InputDecoration(labelText: 'Method'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _paramsCtrl,
                        decoration: const InputDecoration(labelText: 'Parameters (JSON)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _callingApi ? null : _runRawApi,
                      icon: const Icon(Icons.send_rounded, size: 15),
                      label: Text(s.t('Execute', 'Exécuter')),
                    ),
                  ],
                ),
                if (_apiResponse.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 260),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.subtleSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _apiResponse,
                            style: AppTheme.monoStyle.copyWith(fontSize: 12),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          tooltip: 'Copy JSON',
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: _apiResponse)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SpeedMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.monoStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
