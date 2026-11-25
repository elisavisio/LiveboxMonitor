import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class DhcpScreen extends StatefulWidget {
  final AppController controller;
  const DhcpScreen({super.key, required this.controller});

  @override
  State<DhcpScreen> createState() => _DhcpScreenState();
}

class _DhcpScreenState extends State<DhcpScreen> {
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _lanCtrl = TextEditingController();
  final _maskCtrl = TextEditingController();
  bool _enabled = true;
  bool _initialized = false;
  bool _onlyStatic = false;

  void _syncFromController() {
    final cfg = widget.controller.dhcpConfig;
    if (cfg == null || _initialized) return;
    _initialized = true;
    _enabled = cfg.enabled;
    _lanCtrl.text = cfg.lanIp;
    _maskCtrl.text = cfg.subnetMask;
    _minCtrl.text = cfg.minAddress;
    _maxCtrl.text = cfg.maxAddress;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _lanCtrl.dispose();
    _maskCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddBindingDialog() async {
    final s = widget.controller.strings;
    final macCtrl = TextEditingController();
    final ipCtrl = TextEditingController(text: '192.168.1.');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Add Static DHCP Lease', 'Ajouter un bail DHCP fixe')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: macCtrl,
                decoration: const InputDecoration(
                  labelText: 'MAC Address',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IPv4 Address',
                  hintText: '192.168.1.45',
                ),
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
    if (ok == true && macCtrl.text.trim().isNotEmpty && ipCtrl.text.trim().isNotEmpty) {
      await widget.controller.addDhcpBinding(macCtrl.text.trim(), ipCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncFromController();
    final c = widget.controller;
    final s = c.strings;
    final cfg = c.dhcpConfig;
    final bindings = _onlyStatic
        ? c.dhcpBindings.where((b) => b.isStatic).toList()
        : c.dhcpBindings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveRow(
            leftFlex: 3,
            rightFlex: 2,
            breakpoint: 840,
            // DHCPv4 Server Config
            left: SectionCard(
              title: s.t('DHCPv4 Server Configuration', 'Configuration du serveur DHCPv4'),
              icon: Icons.dns_rounded,
              actions: [
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lanCtrl,
                          decoration: InputDecoration(
                            labelText: s.t('Livebox LAN IP', 'IP LAN Livebox'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maskCtrl,
                          decoration: InputDecoration(
                            labelText: s.t('Subnet Mask', 'Masque sous-réseau'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          decoration: InputDecoration(
                            labelText: s.t('Pool Start IP', 'Début de plage'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          decoration: InputDecoration(
                            labelText: s.t('Pool End IP', 'Fin de plage'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: cfg == null
                          ? null
                          : () async {
                              await c.saveDhcpConfig(cfg.copyWith(
                                enabled: _enabled,
                                lanIp: _lanCtrl.text.trim(),
                                subnetMask: _maskCtrl.text.trim(),
                                minAddress: _minCtrl.text.trim(),
                                maxAddress: _maxCtrl.text.trim(),
                              ));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(s.t('DHCP settings saved', 'Configuration DHCP enregistrée')),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: Text(s.apply),
                    ),
                  ),
                ],
              ),
            ),
            // DHCPv6 Info Card
            right: SectionCard(
              title: 'DHCPv6 & Prefix Delegation',
              icon: Icons.hub_rounded,
              iconColor: AppColors.info,
              child: cfg == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        InfoRow(
                          label: 'DHCPv6 Server',
                          value: cfg.dhcpv6Enabled ? s.enabled : s.disabled,
                          valueColor: cfg.dhcpv6Enabled ? AppColors.success : AppColors.warning,
                        ),
                        InfoRow(
                          label: 'Delegated Prefix',
                          value: cfg.ipv6Prefix,
                          mono: true,
                          copyable: true,
                        ),
                        InfoRow(
                          label: s.t('Lease Duration', 'Durée du bail'),
                          value: Formatters.duration(cfg.leaseTimeSeconds),
                          mono: true,
                        ),
                        InfoRow(
                          label: s.t('Static Bindings', 'Baux fixes'),
                          value: '${c.dhcpBindings.where((b) => b.isStatic).length} / ${c.dhcpBindings.length}',
                          mono: true,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // Static Bindings & Leases Table
          SectionCard(
            title: s.t('DHCP Leases & Static Bindings', 'Baux DHCP & Adresses IP fixes'),
            icon: Icons.push_pin_rounded,
            actions: [
              FilterChip(
                label: Text(s.t('Static Only', 'Fixes uniquement')),
                selected: _onlyStatic,
                onSelected: (v) => setState(() => _onlyStatic = v),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _showAddBindingDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(s.t('Add Binding', 'Ajouter')),
              ),
            ],
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 780),
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(s.t('Device', 'Équipement'))),
                    const DataColumn(label: Text('MAC Address')),
                    const DataColumn(label: Text('IPv4 Address')),
                    DataColumn(label: Text(s.t('Type', 'Type'))),
                    DataColumn(label: Text(s.t('Status', 'Statut'))),
                    DataColumn(label: Text(s.t('Actions', 'Actions'))),
                  ],
                  rows: bindings.map((b) {
                    return DataRow(cells: [
                      DataCell(Text(b.deviceName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(b.macAddress, style: AppTheme.monoStyle.copyWith(fontSize: 12))),
                      DataCell(Text(b.ipAddress, style: AppTheme.monoStyle.copyWith(fontSize: 12.5))),
                      DataCell(StatusPill(
                        label: b.isStatic ? 'Static' : 'Dynamic',
                        color: b.isStatic ? AppColors.info : context.textSecondary,
                      )),
                      DataCell(StatusPill(
                        label: b.active ? s.active : s.inactive,
                        color: b.active ? AppColors.success : context.textSecondary,
                        showDot: true,
                      )),
                      DataCell(
                        b.isStatic
                            ? IconButton(
                                tooltip: s.delete,
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.danger),
                                onPressed: () => c.deleteDhcpBinding(b.macAddress),
                              )
                            : TextButton(
                                onPressed: () => c.addDhcpBinding(b.macAddress, b.ipAddress),
                                child: Text(s.t('Pin IP', 'Fixer IP')),
                              ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
