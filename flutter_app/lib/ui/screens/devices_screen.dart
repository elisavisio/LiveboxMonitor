import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

enum _DeviceFilter { all, active, wifi, ethernet, blocked }

class DevicesScreen extends StatefulWidget {
  final AppController controller;
  const DevicesScreen({super.key, required this.controller});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  _DeviceFilter _filter = _DeviceFilter.all;
  String? _selectedMac;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<NetworkDevice> _filteredDevices() {
    final q = _searchCtrl.text.trim().toLowerCase();
    return widget.controller.devices.where((d) {
      switch (_filter) {
        case _DeviceFilter.active:
          if (!d.active) return false;
        case _DeviceFilter.wifi:
          if (!d.isWifi) return false;
        case _DeviceFilter.ethernet:
          if (d.isWifi) return false;
        case _DeviceFilter.blocked:
          if (!d.blocked) return false;
        case _DeviceFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.ipAddress.toLowerCase().contains(q) ||
          d.key.toLowerCase().contains(q) ||
          d.vendor.toLowerCase().contains(q) ||
          d.deviceType.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  Future<void> _showRenameDialog(NetworkDevice device) async {
    final s = widget.controller.strings;
    final ctrl = TextEditingController(text: device.name);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Rename Device', 'Renommer l\'équipement')),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: s.t('Device Name', 'Nom')),
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await widget.controller.renameDevice(device.key, res);
    }
  }

  Future<void> _showTypeDialog(NetworkDevice device) async {
    final s = widget.controller.strings;
    String selected = kDeviceTypeOptions.contains(device.deviceType)
        ? device.deviceType
        : 'Unknown';
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(s.t('Assign Device Type', 'Type d\'équipement')),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              items: kDeviceTypeOptions
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(Formatters.deviceTypeIcon(t), size: 17),
                            const SizedBox(width: 10),
                            Text(t),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setLocal(() => selected = v);
              },
            ),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: Text(s.save)),
          ],
        ),
      ),
    );
    if (res != null) {
      await widget.controller.setDeviceType(device.key, res);
    }
  }

  Future<void> _showStaticIpDialog(NetworkDevice device) async {
    final s = widget.controller.strings;
    final ctrl = TextEditingController(text: device.ipAddress);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Assign Static DHCP IP', 'Attribuer une IP fixe DHCP')),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'IPv4 Address',
              helperText: 'MAC: ${device.key}',
            ),
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      await widget.controller.addDhcpBinding(device.key, res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('Static IP $res bound to ${device.name}', 'IP fixe $res associée'))),
        );
      }
    }
  }

  Widget _buildInspectorBody(BuildContext context, NetworkDevice selected, {bool inSheet = false}) {
    final c = widget.controller;
    final s = c.strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Formatters.deviceTypeIcon(selected.deviceType),
                  color: AppColors.orange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${selected.deviceType} · ${selected.vendor}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: selected.active ? s.online : s.offline,
                color: selected.active ? AppColors.success : context.textSecondary,
                showDot: true,
              ),
              if (inSheet) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Quick Action Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showRenameDialog(selected),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(s.t('Rename', 'Renommer')),
              ),
              OutlinedButton.icon(
                onPressed: () => _showTypeDialog(selected),
                icon: const Icon(Icons.category_outlined, size: 15),
                label: Text(s.t('Type', 'Type')),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await c.wakeOnLan(selected.key);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Wake-on-LAN sent to ${selected.key}'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.power_settings_new_rounded, size: 15),
                label: const Text('Wake-on-LAN'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showStaticIpDialog(selected),
                icon: const Icon(Icons.push_pin_outlined, size: 15),
                label: Text(s.t('Static IP', 'IP Fixe')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: selected.blocked ? AppColors.success : AppColors.danger,
                ),
                onPressed: () => c.setDeviceBlocked(selected.key, !selected.blocked),
                icon: Icon(
                  selected.blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                  size: 15,
                ),
                label: Text(
                  selected.blocked
                      ? s.t('Unblock WAN', 'Débloquer')
                      : s.t('Block WAN', 'Bloquer WAN'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.borderColor),
          const SizedBox(height: 8),

          InfoRow(label: 'MAC Address', value: selected.key, mono: true, copyable: true),
          InfoRow(label: 'IPv4 Address', value: selected.ipAddress, mono: true, copyable: true),
          InfoRow(label: 'IPv6 Address', value: selected.ipv6Address, mono: true, copyable: true),
          InfoRow(label: s.t('Livebox Name', 'Nom Livebox'), value: selected.liveboxName),
          InfoRow(label: s.t('Local DNS', 'DNS Local'), value: selected.dnsName, mono: true),
          InfoRow(label: s.t('Interface', 'Interface'), value: selected.interfaceName),
          InfoRow(
            label: s.t('Link Speed', 'Vitesse lien'),
            value: selected.linkSpeedMbps != null ? '${selected.linkSpeedMbps} Mbps' : '—',
            mono: true,
          ),
          if (selected.isWifi)
            InfoRow(
              label: 'Wi-Fi RSSI',
              value: selected.rssi != null ? '${selected.rssi} dBm' : '—',
              mono: true,
            ),
          InfoRow(
            label: s.t('Total Rx / Tx', 'Total Rx / Tx'),
            value: '${Formatters.bytes(selected.rxBytes)} / ${Formatters.bytes(selected.txBytes)}',
            mono: true,
          ),
          InfoRow(
            label: s.t('First Seen', 'Première vue'),
            value: selected.firstSeen != null ? Formatters.dateTime(selected.firstSeen!) : '—',
            mono: true,
          ),
          InfoRow(
            label: s.t('Last Changed', 'Dernier changement'),
            value: selected.lastChanged != null ? Formatters.dateTime(selected.lastChanged!) : '—',
            mono: true,
          ),

          if (selected.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Tags', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selected.tags
                  .map((tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],

          if (!selected.active) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
              ),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: s.t('Forget Device', 'Supprimer l\'équipement'),
                  message: s.t(
                    'Remove ${selected.name} (${selected.key}) from Livebox history?',
                    'Supprimer ${selected.name} (${selected.key}) de la Livebox ?',
                  ),
                  destructive: true,
                );
                if (ok) {
                  await c.deleteDevice(selected.key);
                  if (inSheet && context.mounted) Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: Text(s.t('Remove Offline Device', 'Supprimer l\'équipement hors ligne')),
            ),
          ],
        ],
      ),
    );
  }

  void _openInspectorSheet(String mac) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (ctx, _) => ListenableBuilder(
          listenable: widget.controller,
          builder: (ctx, _) {
            final dev = widget.controller.devices
                .where((d) => d.key == mac)
                .firstOrNull;
            if (dev == null) {
              return const SizedBox.shrink();
            }
            return SafeArea(
              top: false,
              child: _buildInspectorBody(ctx, dev, inSheet: true),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final devices = _filteredDevices();
    final selected = devices.where((d) => d.key == _selectedMac).firstOrNull ??
        (devices.isNotEmpty ? devices.first : null);

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Filter & Search Toolbar
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: s.t('Filter by name, IP, MAC, vendor...', 'Filtrer par nom, IP, MAC...'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  ChoiceChip(
                    label: Text('${s.t("All", "Tous")} (${c.devices.length})'),
                    selected: _filter == _DeviceFilter.all,
                    onSelected: (_) => setState(() => _filter = _DeviceFilter.all),
                  ),
                  ChoiceChip(
                    label: Text('${s.active} (${c.devices.where((d) => d.active).length})'),
                    selected: _filter == _DeviceFilter.active,
                    onSelected: (_) => setState(() => _filter = _DeviceFilter.active),
                  ),
                  ChoiceChip(
                    label: Text('Wi-Fi (${c.devices.where((d) => d.isWifi).length})'),
                    selected: _filter == _DeviceFilter.wifi,
                    onSelected: (_) => setState(() => _filter = _DeviceFilter.wifi),
                  ),
                  ChoiceChip(
                    label: Text('Ethernet (${c.devices.where((d) => !d.isWifi).length})'),
                    selected: _filter == _DeviceFilter.ethernet,
                    onSelected: (_) => setState(() => _filter = _DeviceFilter.ethernet),
                  ),
                  ChoiceChip(
                    label: Text('${s.t("Blocked", "Bloqués")} (${c.devices.where((d) => d.blocked).length})'),
                    selected: _filter == _DeviceFilter.blocked,
                    onSelected: (_) => setState(() => _filter = _DeviceFilter.blocked),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Adaptive Master-Detail (Split-pane on Desktop/iPad Landscape, Sheet on iPad Portrait)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showSplitPane = constraints.maxWidth >= 900;
                final showRateCol = constraints.maxWidth >= 640;
                final showSignalCol = constraints.maxWidth >= 500;

                final listCard = Card(
                  clipBehavior: Clip.antiAlias,
                  child: devices.isEmpty
                      ? EmptyStateView(
                          icon: Icons.devices_other_rounded,
                          title: s.t('No matching devices', 'Aucun équipement trouvé'),
                          subtitle: s.t('Try clearing your search or filter.', 'Essayez de modifier vos filtres.'),
                        )
                      : ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: context.borderColor),
                          itemBuilder: (context, index) {
                            final d = devices[index];
                            final isSel = showSplitPane && selected?.key == d.key;
                            return Material(
                              color: isSel
                                  ? AppColors.orange.withValues(alpha: context.isDark ? 0.14 : 0.08)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedMac = d.key);
                                  if (!showSplitPane) {
                                    _openInspectorSheet(d.key);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: context.subtleSurface,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSel
                                                    ? AppColors.orange.withValues(alpha: 0.6)
                                                    : context.borderColor,
                                              ),
                                            ),
                                            child: Icon(
                                              Formatters.deviceTypeIcon(d.deviceType),
                                              size: 20,
                                              color: d.active
                                                  ? (d.blocked ? AppColors.danger : AppColors.orange)
                                                  : context.textSecondary,
                                            ),
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              width: 11,
                                              height: 11,
                                              decoration: BoxDecoration(
                                                color: d.blocked
                                                    ? AppColors.danger
                                                    : (d.active
                                                        ? AppColors.success
                                                        : context.textSecondary),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Theme.of(context).cardColor,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    d.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13.5,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (d.blocked) ...[
                                                  const SizedBox(width: 6),
                                                  const StatusPill(
                                                    label: 'Blocked',
                                                    color: AppColors.danger,
                                                  ),
                                                ],
                                                if (d.staticIp) ...[
                                                  const SizedBox(width: 6),
                                                  const StatusPill(
                                                    label: 'Static',
                                                    color: AppColors.info,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${d.vendor.isNotEmpty ? d.vendor : d.deviceType} · ${d.key}',
                                              style: AppTheme.monoStyle.copyWith(
                                                fontSize: 11,
                                                color: context.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 114,
                                        child: Text(
                                          d.ipAddress.isNotEmpty ? d.ipAddress : '—',
                                          style: AppTheme.monoStyle.copyWith(fontSize: 12.5),
                                        ),
                                      ),
                                      if (showSignalCol)
                                        SizedBox(
                                          width: 122,
                                          child: d.isWifi
                                              ? RssiIndicator(rssi: d.rssi)
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.settings_ethernet_rounded,
                                                        size: 14, color: AppColors.info),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        d.interfaceName,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      if (showRateCol)
                                        SizedBox(
                                          width: 88,
                                          child: Text(
                                            d.active
                                                ? Formatters.bytesPerSecAsBitrate(d.rxBytesPerSec)
                                                : s.offline,
                                            textAlign: TextAlign.right,
                                            style: AppTheme.monoStyle.copyWith(
                                              fontSize: 11.5,
                                              color: d.active
                                                  ? AppColors.info
                                                  : context.textSecondary,
                                            ),
                                          ),
                                        ),
                                      if (!showSplitPane) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded,
                                            size: 18, color: context.textSecondary),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                );

                if (!showSplitPane) {
                  return listCard;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: listCard),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: selected == null
                          ? Card(
                              child: EmptyStateView(
                                icon: Icons.touch_app_rounded,
                                title: s.t('Select a device', 'Sélectionnez un équipement'),
                              ),
                            )
                          : Card(
                              child: _buildInspectorBody(context, selected),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
