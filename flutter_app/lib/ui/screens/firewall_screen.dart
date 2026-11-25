import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class FirewallScreen extends StatefulWidget {
  final AppController controller;
  const FirewallScreen({super.key, required this.controller});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  static const _levels = ['Low', 'Medium', 'High', 'Custom'];

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      case 'high':
        return AppColors.success;
      default:
        return AppColors.purple;
    }
  }

  Future<void> _showAddRuleDialog() async {
    final s = widget.controller.strings;
    final descCtrl = TextEditingController();
    final srcCtrl = TextEditingController(text: '0.0.0.0/0');
    final dstCtrl = TextEditingController(text: '192.168.1.');
    final portCtrl = TextEditingController();
    bool isIpv6 = false;
    String action = 'Accept';
    String proto = 'TCP';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.t('New Custom Firewall Rule', 'Nouvelle règle pare-feu')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: s.t('Description', 'Description')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: action,
                        decoration: InputDecoration(labelText: s.t('Action', 'Action')),
                        items: const [
                          DropdownMenuItem(value: 'Accept', child: Text('Accept')),
                          DropdownMenuItem(value: 'Drop', child: Text('Drop')),
                        ],
                        onChanged: (v) => setLocal(() => action = v ?? 'Accept'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: proto,
                        decoration: InputDecoration(labelText: s.t('Protocol', 'Protocole')),
                        items: const [
                          DropdownMenuItem(value: 'TCP', child: Text('TCP')),
                          DropdownMenuItem(value: 'UDP', child: Text('UDP')),
                          DropdownMenuItem(value: 'ICMP', child: Text('ICMP')),
                          DropdownMenuItem(value: 'All', child: Text('All')),
                        ],
                        onChanged: (v) => setLocal(() => proto = v ?? 'TCP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('IPv6 Rule'),
                  value: isIpv6,
                  onChanged: (v) => setLocal(() {
                    isIpv6 = v;
                    srcCtrl.text = v ? '::/0' : '0.0.0.0/0';
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: srcCtrl,
                  decoration: InputDecoration(labelText: s.t('Source Prefix', 'Préfixe source')),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: dstCtrl,
                        decoration: InputDecoration(labelText: s.t('Destination IP/Prefix', 'IP Destination')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: portCtrl,
                        decoration: InputDecoration(labelText: s.t('Dst Port', 'Port Dest')),
                      ),
                    ),
                  ],
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

    if (ok == true && descCtrl.text.trim().isNotEmpty) {
      await widget.controller.saveFirewallRule(FirewallRule(
        id: 'fw_${DateTime.now().millisecondsSinceEpoch % 100000}',
        enabled: true,
        isIpv6: isIpv6,
        action: action,
        protocol: proto,
        sourcePrefix: srcCtrl.text.trim(),
        sourcePort: '',
        destinationPrefix: dstCtrl.text.trim(),
        destinationPort: portCtrl.text.trim(),
        description: descCtrl.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final fw = c.firewall;
    if (fw == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveRow(
            leftFlex: 3,
            rightFlex: 2,
            breakpoint: 840,
            left: SectionCard(
              title: s.t('Firewall Security Levels', 'Niveaux de sécurité du pare-feu'),
              subtitle: s.t(
                'Select predefined protection profiles or switch to Custom for fine-grained rules.',
                'Choisissez un niveau de protection prédéfini ou Personnalisé.',
              ),
              icon: Icons.shield_rounded,
              iconColor: _levelColor(fw.ipv4Level),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IPv4 Firewall',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: _levels
                          .map((l) => ButtonSegment(value: l, label: Text(l)))
                          .toList(),
                      selected: {
                        _levels.contains(fw.ipv4Level) ? fw.ipv4Level : 'Medium',
                      },
                      onSelectionChanged: (v) =>
                          c.setFirewallLevels(v.first, fw.ipv6Level),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('IPv6 Firewall',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: _levels
                          .map((l) => ButtonSegment(value: l, label: Text(l)))
                          .toList(),
                      selected: {
                        _levels.contains(fw.ipv6Level) ? fw.ipv6Level : 'Medium',
                      },
                      onSelectionChanged: (v) =>
                          c.setFirewallLevels(fw.ipv4Level, v.first),
                    ),
                  ),
                ],
              ),
            ),
            right: SectionCard(
              title: s.t('ICMP Ping Responses', 'Réponses au Ping (ICMP)'),
              subtitle: s.t(
                'Control whether Livebox replies to WAN ping probes.',
                'Contrôle la réponse aux requêtes ping depuis Internet.',
              ),
              icon: Icons.radar_rounded,
              iconColor: AppColors.info,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Respond to IPv4 Ping', style: TextStyle(fontSize: 13.5)),
                    subtitle: Text(
                      fw.respondToPingIpv4 ? s.enabled : s.disabled,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                    value: fw.respondToPingIpv4,
                    onChanged: (v) => c.setRespondToPing(v, fw.respondToPingIpv6),
                  ),
                  Divider(height: 1, color: context.borderColor),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Respond to IPv6 Ping', style: TextStyle(fontSize: 13.5)),
                    subtitle: Text(
                      fw.respondToPingIpv6 ? s.enabled : s.disabled,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                    value: fw.respondToPingIpv6,
                    onChanged: (v) => c.setRespondToPing(fw.respondToPingIpv4, v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Custom Firewall Rules Table
          SectionCard(
            title: s.t('Custom Firewall Rules', 'Règles personnalisées du pare-feu'),
            icon: Icons.gavel_rounded,
            actions: [
              FilledButton.icon(
                onPressed: _showAddRuleDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(s.t('Add Rule', 'Ajouter')),
              ),
            ],
            padding: EdgeInsets.zero,
            child: fw.rules.isEmpty
                ? EmptyStateView(
                    icon: Icons.verified_user_outlined,
                    title: s.t('No custom firewall rules', 'Aucune règle personnalisée'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 820),
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(s.t('Enabled', 'Actif'))),
                          DataColumn(label: Text(s.t('Description', 'Description'))),
                          const DataColumn(label: Text('IP')),
                          DataColumn(label: Text(s.t('Action', 'Action'))),
                          DataColumn(label: Text(s.t('Protocol', 'Protocole'))),
                          DataColumn(label: Text(s.t('Source', 'Source'))),
                          DataColumn(label: Text(s.t('Destination', 'Destination'))),
                          DataColumn(label: Text(s.t('Actions', 'Actions'))),
                        ],
                        rows: fw.rules.map((r) {
                          return DataRow(cells: [
                            DataCell(Switch(
                              value: r.enabled,
                              onChanged: (v) => c.saveFirewallRule(r.copyWith(enabled: v)),
                            )),
                            DataCell(Text(r.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(StatusPill(
                              label: r.isIpv6 ? 'IPv6' : 'IPv4',
                              color: r.isIpv6 ? AppColors.purple : AppColors.info,
                            )),
                            DataCell(StatusPill(
                              label: r.action,
                              color: r.action.toLowerCase() == 'accept'
                                  ? AppColors.success
                                  : AppColors.danger,
                            )),
                            DataCell(Text(r.protocol, style: AppTheme.monoStyle.copyWith(fontSize: 12))),
                            DataCell(Text(
                              r.sourcePrefix.isEmpty ? 'Any' : r.sourcePrefix,
                              style: AppTheme.monoStyle.copyWith(fontSize: 12),
                            )),
                            DataCell(Text(
                              '${r.destinationPrefix}${r.destinationPort.isNotEmpty ? ":${r.destinationPort}" : ""}',
                              style: AppTheme.monoStyle.copyWith(fontSize: 12),
                            )),
                            DataCell(IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.danger),
                              onPressed: () => c.deleteFirewallRule(r.id),
                            )),
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
