import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class PhoneScreen extends StatefulWidget {
  final AppController controller;
  const PhoneScreen({super.key, required this.controller});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  Future<void> _showContactDialog({PhoneContact? existing}) async {
    final s = widget.controller.strings;
    final firstCtrl = TextEditingController(text: existing?.firstName ?? '');
    final lastCtrl = TextEditingController(text: existing?.lastName ?? '');
    final cellCtrl = TextEditingController(text: existing?.cellNumber ?? '');
    final homeCtrl = TextEditingController(text: existing?.homeNumber ?? '');
    final workCtrl = TextEditingController(text: existing?.workNumber ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? s.t('Add Contact', 'Nouveau contact')
            : s.t('Edit Contact', 'Modifier le contact')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstCtrl,
                      decoration: InputDecoration(labelText: s.t('First Name', 'Prénom')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lastCtrl,
                      decoration: InputDecoration(labelText: s.t('Last Name', 'Nom')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cellCtrl,
                decoration: InputDecoration(labelText: s.t('Mobile', 'Mobile')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: homeCtrl,
                decoration: InputDecoration(labelText: s.t('Home', 'Domicile')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: workCtrl,
                decoration: InputDecoration(labelText: s.t('Work', 'Travail')),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.save)),
        ],
      ),
    );

    if (ok == true && (firstCtrl.text.trim().isNotEmpty || lastCtrl.text.trim().isNotEmpty)) {
      await widget.controller.saveContact(PhoneContact(
        id: existing?.id ?? '',
        firstName: firstCtrl.text.trim(),
        lastName: lastCtrl.text.trim(),
        cellNumber: cellCtrl.text.trim(),
        homeNumber: homeCtrl.text.trim(),
        workNumber: workCtrl.text.trim(),
      ));
    }
  }

  Widget _callTypeBadge(CallType type) {
    return switch (type) {
      CallType.incoming => const StatusPill(
          label: 'Incoming',
          color: AppColors.success,
          icon: Icons.call_received_rounded,
        ),
      CallType.outgoing => const StatusPill(
          label: 'Outgoing',
          color: AppColors.info,
          icon: Icons.call_made_rounded,
        ),
      CallType.missed => const StatusPill(
          label: 'Missed',
          color: AppColors.danger,
          icon: Icons.call_missed_rounded,
        ),
      CallType.failed => const StatusPill(
          label: 'Failed',
          color: AppColors.warning,
          icon: Icons.phone_disabled_rounded,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;

          final callLogCard = Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.orange, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('VoIP Call History', 'Journal des appels VoIP'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              c.info?.voipNumber ?? '',
                              style: AppTheme.monoStyle.copyWith(
                                fontSize: 11.5,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await c.ringPhones();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(s.t('Ringing connected handsets...', 'Sonnerie des combinés...')),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications_active_outlined, size: 16),
                        label: Text(s.t('Ring Test', 'Faire sonner')),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.borderColor),
                Expanded(
                  child: c.calls.isEmpty
                      ? EmptyStateView(
                          icon: Icons.phone_rounded,
                          title: s.t('No calls in history', 'Aucun appel dans le journal'),
                        )
                      : ListView.separated(
                          itemCount: c.calls.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: context.borderColor),
                          itemBuilder: (context, index) {
                            final call = c.calls[index];
                            return ListTile(
                              leading: _callTypeBadge(call.type),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      call.contactName.isNotEmpty ? call.contactName : call.number,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                    ),
                                  ),
                                  if (call.isSpam) ...[
                                    const SizedBox(width: 8),
                                    const StatusPill(label: 'SPAM', color: AppColors.danger),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${call.number} · ${Formatters.dateShort(call.timestamp)}',
                                style: AppTheme.monoStyle.copyWith(
                                  fontSize: 11.5,
                                  color: context.textSecondary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    call.durationSeconds > 0
                                        ? Formatters.duration(call.durationSeconds)
                                        : '—',
                                    style: AppTheme.monoStyle.copyWith(
                                      fontSize: 12,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                                    onPressed: () => c.deleteCall(call.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );

          final contactsCard = Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.contacts_rounded, color: AppColors.info, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${s.t("Livebox Contacts", "Contacts Livebox")} (${c.contacts.length})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showContactDialog(),
                        icon: const Icon(Icons.person_add_outlined, size: 16),
                        label: Text(s.add),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.borderColor),
                Expanded(
                  child: c.contacts.isEmpty
                      ? EmptyStateView(
                          icon: Icons.contact_phone_outlined,
                          title: s.t('No contacts saved', 'Aucun contact'),
                        )
                      : ListView.separated(
                          itemCount: c.contacts.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: context.borderColor),
                          itemBuilder: (context, index) {
                            final ct = c.contacts[index];
                            final numbers = [
                              if (ct.cellNumber.isNotEmpty) 'M: ${ct.cellNumber}',
                              if (ct.homeNumber.isNotEmpty) 'H: ${ct.homeNumber}',
                              if (ct.workNumber.isNotEmpty) 'W: ${ct.workNumber}',
                            ].join(' · ');
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.orange.withValues(alpha: 0.16),
                                foregroundColor: AppColors.orange,
                                child: Text(
                                  ct.fullName.isNotEmpty ? ct.fullName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(ct.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              subtitle: Text(numbers,
                                  style: AppTheme.monoStyle.copyWith(fontSize: 11.5)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 17),
                                    onPressed: () => _showContactDialog(existing: ct),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        size: 17, color: AppColors.danger),
                                    onPressed: () => c.deleteContact(ct.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: callLogCard),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: contactsCard),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: callLogCard),
              const SizedBox(height: 16),
              Expanded(child: contactsCard),
            ],
          );
        },
      ),
    );
  }
}
