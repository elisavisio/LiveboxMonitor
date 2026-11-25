import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class RepeatersScreen extends StatefulWidget {
  final AppController controller;
  const RepeatersScreen({super.key, required this.controller});

  @override
  State<RepeatersScreen> createState() => _RepeatersScreenState();
}

class _RepeatersScreenState extends State<RepeatersScreen> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final repeaters = c.repeaters;

    if (repeaters.isEmpty) {
      return EmptyStateView(
        icon: Icons.wifi_tethering_off_rounded,
        title: s.t('No Orange Wi-Fi Repeaters detected', 'Aucun Répéteur Wi-Fi détecté'),
        subtitle: s.t(
          'Orange Wi-Fi 5, 6, and 7 Repeaters connected to your Livebox appear here automatically.',
          'Les répéteurs Wi-Fi 5, 6 et 7 Orange connectés à la Livebox apparaissent ici automatiquement.',
        ),
      );
    }

    final selected = repeaters.where((r) => r.key == _selectedKey).firstOrNull ??
        repeaters.first;
    final attachedDevices = c.devices
        .where((d) => selected.connectedDeviceKeys.contains(d.key))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Repeater selector pills
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: repeaters.map((rep) {
              final isSel = rep.key == selected.key;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedKey = rep.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.orange.withValues(alpha: 0.14)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? AppColors.orange : context.borderColor,
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        color: rep.active ? AppColors.orange : context.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rep.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text('${rep.ipAddress} · ${rep.backhaulType}',
                              style: AppTheme.monoStyle.copyWith(fontSize: 11, color: context.textSecondary)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      StatusPill(
                        label: rep.active ? s.online : s.offline,
                        color: rep.active ? AppColors.success : context.textSecondary,
                        showDot: true,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // KPI row for selected repeater (responsive wrap)
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 760 ? 3 : 1;
              final cardW = (constraints.maxWidth - (cols - 1) * 14) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: cardW,
                    child: KpiCard(
                      title: s.t('Backhaul Link', 'Lien Backhaul'),
                      value: selected.backhaulType,
                      subtitle: selected.backhaulRssi != null
                          ? 'RSSI ${selected.backhaulRssi} dBm'
                          : 'Wired Gigabit Link',
                      icon: selected.backhaulRssi != null
                          ? Icons.wifi_rounded
                          : Icons.settings_ethernet_rounded,
                      accentColor: AppColors.info,
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: KpiCard(
                      title: s.t('Uptime', 'Disponibilité'),
                      value: Formatters.duration(selected.uptimeSeconds),
                      subtitle: selected.softwareVersion,
                      icon: Icons.timer_outlined,
                      accentColor: AppColors.purple,
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: KpiCard(
                      title: s.t('Connected Clients', 'Clients connectés'),
                      value: '${selected.connectedDevicesCount}',
                      subtitle: selected.model,
                      icon: Icons.devices_rounded,
                      accentColor: AppColors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          ResponsiveRow(
            breakpoint: 840,
            left: SectionCard(
              title: '${selected.name} · ${s.t("Details & Controls", "Détails & Contrôles")}',
              icon: Icons.tune_rounded,
              actions: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: s.t('Reboot Repeater', 'Redémarrer le répéteur'),
                      message: s.t(
                        'Reboot ${selected.name} (${selected.ipAddress})?',
                        'Redémarrer ${selected.name} (${selected.ipAddress}) ?',
                      ),
                      destructive: true,
                    );
                    if (ok) await c.rebootRepeater(selected.key);
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.danger),
                  label: Text(s.t('Reboot', 'Redémarrer')),
                ),
              ],
              child: Column(
                children: [
                  InfoRow(label: s.t('Model', 'Modèle'), value: selected.model),
                  InfoRow(label: 'MAC Address', value: selected.key, mono: true, copyable: true),
                  InfoRow(label: 'IP Address', value: selected.ipAddress, mono: true, copyable: true),
                  InfoRow(label: 'Firmware', value: selected.softwareVersion, mono: true),
                  Divider(height: 20, color: context.borderColor),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.t('Repeater Wi-Fi Broadcast', 'Diffusion Wi-Fi du répéteur'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    subtitle: Text(selected.wifiEnabled ? s.enabled : s.disabled,
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    value: selected.wifiEnabled,
                    onChanged: (v) => c.setRepeaterWifi(selected.key, v),
                  ),
                ],
              ),
            ),
            right: Column(
              children: [
                SectionCard(
                  title: s.t('Clients via this Repeater', 'Clients sur ce répéteur'),
                  icon: Icons.devices_other_rounded,
                  child: attachedDevices.isEmpty
                      ? Text(
                          s.t('No individual clients mapped.', 'Aucun client mappé.'),
                          style: TextStyle(color: context.textSecondary, fontSize: 13),
                        )
                      : Column(
                          children: attachedDevices
                              .map((d) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Formatters.deviceTypeIcon(d.deviceType),
                                        color: AppColors.orange, size: 19),
                                    title: Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    subtitle: Text('${d.ipAddress} · ${d.key}',
                                        style: AppTheme.monoStyle.copyWith(fontSize: 11)),
                                    trailing: RssiIndicator(rssi: d.rssi),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: s.t('Repeater Reboot History', 'Historique des redémarrages'),
                  icon: Icons.history_rounded,
                  child: selected.rebootHistory.isEmpty
                      ? Text(s.t('No reboot entries.', 'Aucun historique.'),
                          style: TextStyle(color: context.textSecondary))
                      : Column(
                          children: selected.rebootHistory
                              .map((r) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.restart_alt_rounded,
                                        size: 18, color: AppColors.warning),
                                    title: Text(r.bootReason,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    subtitle: Text(Formatters.dateTime(r.bootDate),
                                        style: AppTheme.monoStyle.copyWith(fontSize: 11.5)),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
