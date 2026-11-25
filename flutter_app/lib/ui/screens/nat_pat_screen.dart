import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class NatPatScreen extends StatefulWidget {
  final AppController controller;
  const NatPatScreen({super.key, required this.controller});

  @override
  State<NatPatScreen> createState() => _NatPatScreenState();
}

class _NatPatScreenState extends State<NatPatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddPatDialog() async {
    final s = widget.controller.strings;
    final nameCtrl = TextEditingController();
    final extPortCtrl = TextEditingController();
    final intPortCtrl = TextEditingController();
    final ipCtrl = TextEditingController(text: '192.168.1.');
    final extIpCtrl = TextEditingController(text: 'All');
    String proto = 'TCP';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.t('New Port Forwarding Rule', 'Nouvelle règle NAT/PAT')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: s.t('Rule Name', 'Nom de la règle')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: proto,
                  decoration: InputDecoration(labelText: s.t('Protocol', 'Protocole')),
                  items: const [
                    DropdownMenuItem(value: 'TCP', child: Text('TCP')),
                    DropdownMenuItem(value: 'UDP', child: Text('UDP')),
                    DropdownMenuItem(value: 'TCP/UDP', child: Text('TCP / UDP')),
                  ],
                  onChanged: (v) => setLocal(() => proto = v ?? 'TCP'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: extPortCtrl,
                        decoration: InputDecoration(labelText: s.t('External Port', 'Port externe')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: intPortCtrl,
                        decoration: InputDecoration(labelText: s.t('Internal Port', 'Port interne')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipCtrl,
                  decoration: InputDecoration(labelText: s.t('Destination IP', 'IP de destination')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: extIpCtrl,
                  decoration: InputDecoration(labelText: s.t('Allowed Source IPs', 'IPs sources autorisées')),
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

    if (ok == true && nameCtrl.text.trim().isNotEmpty && extPortCtrl.text.trim().isNotEmpty) {
      await widget.controller.saveNatPatRule(NatPatRule(
        id: 'webui_${DateTime.now().millisecondsSinceEpoch % 100000}',
        name: nameCtrl.text.trim(),
        type: 'IPv4',
        enabled: true,
        protocol: proto,
        externalPort: extPortCtrl.text.trim(),
        internalPort: intPortCtrl.text.trim().isEmpty
            ? extPortCtrl.text.trim()
            : intPortCtrl.text.trim(),
        destinationIp: ipCtrl.text.trim(),
        externalIps: extIpCtrl.text.trim().isEmpty ? 'All' : extIpCtrl.text.trim(),
        description: nameCtrl.text.trim(),
      ));
    }
  }

  Future<void> _showAddPtfDialog() async {
    final s = widget.controller.strings;
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController(text: '192.168.1.');
    String proto = 'ESP';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.t('New Protocol Forwarding Rule', 'Nouvelle règle de protocole')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: s.t('Rule Name', 'Nom')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: proto,
                  decoration: InputDecoration(labelText: s.t('Protocol', 'Protocole')),
                  items: const [
                    DropdownMenuItem(value: 'ESP', child: Text('ESP (IPsec)')),
                    DropdownMenuItem(value: 'AH', child: Text('AH (IPsec)')),
                    DropdownMenuItem(value: 'GRE', child: Text('GRE')),
                    DropdownMenuItem(value: 'ICMP', child: Text('ICMP')),
                  ],
                  onChanged: (v) => setLocal(() => proto = v ?? 'ESP'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipCtrl,
                  decoration: InputDecoration(labelText: s.t('Destination IP', 'IP destination')),
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
    if (ok == true && nameCtrl.text.trim().isNotEmpty && ipCtrl.text.trim().isNotEmpty) {
      await widget.controller.savePtfRule(PtfRule(
        id: 'ptf_${DateTime.now().millisecondsSinceEpoch % 100000}',
        name: nameCtrl.text.trim(),
        enabled: true,
        protocol: proto,
        destinationIp: ipCtrl.text.trim(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Card(
            child: TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: '${s.t("Port Forwarding (PAT / UPnP)", "Transfert de ports (PAT / UPnP)")} (${c.natPatRules.length})'),
                Tab(text: '${s.t("Protocol Forwarding (PTF)", "Transfert de protocole (PTF)")} (${c.ptfRules.length})'),
                Tab(text: 'DMZ ${c.dmz.enabled ? "(Active)" : ""}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Tab 1: PAT + UPnP
                SingleChildScrollView(
                  child: SectionCard(
                    title: s.t('Port Forwarding Rules', 'Règles de transfert de ports'),
                    icon: Icons.alt_route_rounded,
                    actions: [
                      FilledButton.icon(
                        onPressed: _showAddPatDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(s.t('Add Rule', 'Ajouter')),
                      ),
                    ],
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 820),
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(s.t('Enabled', 'Actif'))),
                            DataColumn(label: Text(s.t('Name', 'Nom'))),
                            DataColumn(label: Text(s.t('Origin', 'Origine'))),
                            DataColumn(label: Text(s.t('Protocol', 'Protocole'))),
                            DataColumn(label: Text(s.t('Ext → Int Port', 'Port Ext → Int'))),
                            DataColumn(label: Text(s.t('Destination IP', 'IP Destination'))),
                            DataColumn(label: Text(s.t('Source IPs', 'Sources'))),
                            DataColumn(label: Text(s.t('Actions', 'Actions'))),
                          ],
                          rows: c.natPatRules.map((r) {
                            return DataRow(cells: [
                              DataCell(Switch(
                                value: r.enabled,
                                onChanged: (v) => c.saveNatPatRule(r.copyWith(enabled: v)),
                              )),
                              DataCell(Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(StatusPill(
                                label: r.type,
                                color: r.type == 'UPnP' ? AppColors.purple : AppColors.info,
                              )),
                              DataCell(StatusPill(label: r.protocol, color: AppColors.orange)),
                              DataCell(Text('${r.externalPort} → ${r.internalPort}',
                                  style: AppTheme.monoStyle.copyWith(fontSize: 12.5))),
                              DataCell(Text(r.destinationIp,
                                  style: AppTheme.monoStyle.copyWith(fontSize: 12.5))),
                              DataCell(Text(r.externalIps,
                                  style: AppTheme.monoStyle.copyWith(fontSize: 12))),
                              DataCell(IconButton(
                                tooltip: s.delete,
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.danger),
                                onPressed: () => c.deleteNatPatRule(r),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Tab 2: Protocol Forwarding
                SingleChildScrollView(
                  child: SectionCard(
                    title: s.t('Protocol Forwarding Rules', 'Règles de transfert de protocoles'),
                    icon: Icons.compare_arrows_rounded,
                    actions: [
                      FilledButton.icon(
                        onPressed: _showAddPtfDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(s.t('Add Rule', 'Ajouter')),
                      ),
                    ],
                    padding: EdgeInsets.zero,
                    child: c.ptfRules.isEmpty
                        ? EmptyStateView(
                            icon: Icons.compare_arrows_rounded,
                            title: s.t('No protocol forwarding rules', 'Aucune règle PTF'),
                          )
                        : DataTable(
                            columns: [
                              DataColumn(label: Text(s.t('Name', 'Nom'))),
                              DataColumn(label: Text(s.t('Protocol', 'Protocole'))),
                              DataColumn(label: Text(s.t('Destination IP', 'IP Destination'))),
                              DataColumn(label: Text(s.t('Status', 'Statut'))),
                              DataColumn(label: Text(s.t('Actions', 'Actions'))),
                            ],
                            rows: c.ptfRules
                                .map((r) => DataRow(cells: [
                                      DataCell(Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(StatusPill(label: r.protocol, color: AppColors.orange)),
                                      DataCell(Text(r.destinationIp, style: AppTheme.monoStyle)),
                                      DataCell(StatusPill(
                                        label: r.enabled ? s.enabled : s.disabled,
                                        color: r.enabled ? AppColors.success : context.textSecondary,
                                      )),
                                      DataCell(IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded,
                                            size: 18, color: AppColors.danger),
                                        onPressed: () => c.deletePtfRule(r.id),
                                      )),
                                    ]))
                                .toList(),
                          ),
                  ),
                ),

                // Tab 3: DMZ
                _DmzPanel(controller: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DmzPanel extends StatefulWidget {
  final AppController controller;
  const _DmzPanel({required this.controller});

  @override
  State<_DmzPanel> createState() => _DmzPanelState();
}

class _DmzPanelState extends State<_DmzPanel> {
  late bool _enabled;
  late TextEditingController _ipCtrl;
  late TextEditingController _extCtrl;

  @override
  void initState() {
    super.initState();
    _enabled = widget.controller.dmz.enabled;
    _ipCtrl = TextEditingController(text: widget.controller.dmz.destinationIp);
    _extCtrl = TextEditingController(text: widget.controller.dmz.externalIps);
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _extCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.strings;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SectionCard(
          title: 'DMZ (Demilitarized Zone)',
          subtitle: s.t(
            'Exposes a single LAN host directly to unsolicited WAN traffic. Use with caution.',
            'Expose directement un équipement LAN au trafic entrant WAN. À utiliser avec précaution.',
          ),
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.warning,
          actions: [
            Switch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ipCtrl,
                enabled: _enabled,
                decoration: InputDecoration(
                  labelText: s.t('DMZ Destination LAN IP', 'Adresse IP LAN DMZ'),
                  hintText: '192.168.1.250',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _extCtrl,
                enabled: _enabled,
                decoration: InputDecoration(
                  labelText: s.t('Allowed External IPs (optional)', 'IPs externes autorisées (optionnel)'),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    await widget.controller.saveDmz(DmzConfig(
                      enabled: _enabled,
                      destinationIp: _ipCtrl.text.trim(),
                      externalIps: _extCtrl.text.trim(),
                    ));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.t('DMZ configuration saved', 'Configuration DMZ enregistrée'))),
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
      ),
    );
  }
}
