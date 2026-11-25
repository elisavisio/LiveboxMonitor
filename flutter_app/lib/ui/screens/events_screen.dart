import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class EventsScreen extends StatefulWidget {
  final AppController controller;
  const EventsScreen({super.key, required this.controller});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedDeviceKey; // null = All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _reasonColor(String reason) {
    final r = reason.toLowerCase();
    if (r.contains('block') || r.contains('delete') || r.contains('error')) {
      return AppColors.danger;
    }
    if (r.contains('active') || r.contains('restore') || r.contains('wol')) {
      return AppColors.success;
    }
    if (r.contains('firewall') || r.contains('reboot')) {
      return AppColors.warning;
    }
    if (r.contains('wifi') || r.contains('stat')) {
      return AppColors.info;
    }
    return AppColors.orange;
  }

  void _showPayloadDialog(LiveboxEvent ev) {
    final pretty = const JsonEncoder.withIndent('  ').convert(ev.rawPayload);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: AppColors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('${ev.deviceName} · ${ev.reason}')),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.subtleSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                pretty,
                style: AppTheme.monoStyle.copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pretty));
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy JSON'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.controller.strings.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final q = _searchCtrl.text.trim().toLowerCase();

    final events = c.events.where((ev) {
      if (_selectedDeviceKey != null && ev.deviceKey != _selectedDeviceKey) {
        return false;
      }
      if (q.isEmpty) return true;
      return ev.deviceName.toLowerCase().contains(q) ||
          ev.reason.toLowerCase().contains(q) ||
          ev.summary.toLowerCase().contains(q) ||
          ev.deviceKey.toLowerCase().contains(q);
    }).toList();

    // Unique devices with event counts
    final counts = <String, ({String name, int count})>{};
    for (final ev in c.events) {
      final cur = counts[ev.deviceKey];
      counts[ev.deviceKey] = (name: ev.deviceName, count: (cur?.count ?? 0) + 1);
    }

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Toolbar
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 290,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: s.t('Search events...', 'Rechercher un événement...'),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: c.togglePollingPaused,
                    icon: Icon(
                      c.pollingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 16,
                    ),
                    label: Text(
                      c.pollingPaused ? s.t('Resume Stream', 'Reprendre') : s.t('Pause', 'Pause'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: events.isEmpty
                        ? null
                        : () {
                            final csv = [
                              'Timestamp;Device;MAC;Reason;Summary',
                              ...events.map((e) =>
                                  '${Formatters.dateTime(e.timestamp)};${e.deviceName};${e.deviceKey};${e.reason};${e.summary}'),
                            ].join('\n');
                            Clipboard.setData(ClipboardData(text: csv));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  s.t('Copied ${events.length} events as CSV',
                                      '${events.length} événements copiés en CSV'),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(s.exportCsv),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: c.events.isEmpty ? null : c.clearEvents,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: Text(s.t('Clear', 'Vider')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left device filter list
                SizedBox(
                  width: 260,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      children: [
                        ListTile(
                          selected: _selectedDeviceKey == null,
                          selectedTileColor: AppColors.orange.withValues(alpha: 0.12),
                          leading: const Icon(Icons.all_inclusive_rounded, size: 18),
                          title: Text(s.t('All Sources', 'Toutes les sources'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: StatusPill(
                            label: '${c.events.length}',
                            color: AppColors.orange,
                          ),
                          onTap: () => setState(() => _selectedDeviceKey = null),
                        ),
                        Divider(height: 1, color: context.borderColor),
                        ...counts.entries.map((e) => ListTile(
                              dense: true,
                              selected: _selectedDeviceKey == e.key,
                              selectedTileColor: AppColors.orange.withValues(alpha: 0.12),
                              title: Text(e.value.name,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(e.key,
                                  style: AppTheme.monoStyle.copyWith(fontSize: 10.5)),
                              trailing: Text('${e.value.count}',
                                  style: AppTheme.monoStyle.copyWith(fontSize: 11.5)),
                              onTap: () => setState(() => _selectedDeviceKey = e.key),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right live event log
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: events.isEmpty
                        ? EmptyStateView(
                            icon: Icons.notifications_none_rounded,
                            title: s.t('No events recorded yet', 'Aucun événement enregistré'),
                            subtitle: s.t(
                              'Livebox sysbus events will appear here automatically.',
                              'Les événements Livebox apparaîtront ici automatiquement.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: events.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: context.borderColor),
                            itemBuilder: (context, index) {
                              final ev = events[index];
                              return InkWell(
                                onTap: () => _showPayloadDialog(ev),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 72,
                                        child: Text(
                                          Formatters.timeHms(ev.timestamp),
                                          style: AppTheme.monoStyle.copyWith(
                                            fontSize: 11.5,
                                            color: context.textSecondary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 130,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: StatusPill(
                                            label: ev.reason,
                                            color: _reasonColor(ev.reason),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 160,
                                        child: Text(
                                          ev.deviceName,
                                          style: const TextStyle(
                                              fontSize: 12.5, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          ev.summary,
                                          style: TextStyle(
                                              fontSize: 12.5, color: context.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 18, color: context.textSecondary),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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
