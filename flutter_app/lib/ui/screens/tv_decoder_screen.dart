import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class TvDecoderScreen extends StatefulWidget {
  final AppController controller;
  const TvDecoderScreen({super.key, required this.controller});

  @override
  State<TvDecoderScreen> createState() => _TvDecoderScreenState();
}

class _TvDecoderScreenState extends State<TvDecoderScreen> {
  String? _selectedKey;

  // Real Orange TV Decoder keycodes (from LmTvDecoderApi.py)
  static const int kPower = 116;
  static const int kMute = 113;
  static const int kVolDown = 114;
  static const int kVolUp = 115;
  static const int kChUp = 402;
  static const int kChDown = 403;
  static const int kUp = 103;
  static const int kDown = 108;
  static const int kLeft = 105;
  static const int kRight = 106;
  static const int kOk = 352;
  static const int kBack = 158;
  static const int kMenu = 139;
  static const int kPlay = 164;
  static const int kRew = 168;
  static const int kFfwd = 159;
  static const int kRec = 167;

  static const _quickChannels = [
    (num: 1, name: 'TF1 4K'),
    (num: 2, name: 'France 2 UHD'),
    (num: 3, name: 'France 3'),
    (num: 4, name: 'Canal+ UHD'),
    (num: 5, name: 'France 5'),
    (num: 6, name: 'M6'),
    (num: 7, name: 'ARTE HD'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final decoders = c.tvDecoders;

    if (decoders.isEmpty) {
      return EmptyStateView(
        icon: Icons.tv_off_rounded,
        title: s.t('No Orange TV Decoders detected', 'Aucun Décodeur TV Orange détecté'),
        subtitle: s.t(
          'Orange TV UHD / Play / TV4 decoders on your LAN appear here with live status & virtual remote.',
          'Les décodeurs TV UHD / Play / TV4 apparaissent ici avec leur état et télécommande virtuelle.',
        ),
      );
    }

    final decoder = decoders.where((d) => d.key == _selectedKey).firstOrNull ??
        decoders.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final infoColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Now Playing Hero Banner
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: decoder.standby
                            ? [context.subtleSurface, Theme.of(context).cardColor]
                            : [
                                AppColors.orange.withValues(alpha: 0.22),
                                Theme.of(context).cardColor,
                              ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: decoder.standby
                                ? context.subtleSurface
                                : AppColors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: decoder.standby
                                  ? context.borderColor
                                  : AppColors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            decoder.standby ? Icons.power_settings_new_rounded : Icons.live_tv_rounded,
                            size: 32,
                            color: decoder.standby ? context.textSecondary : AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  StatusPill(
                                    label: decoder.standby
                                        ? s.t('Standby', 'En veille')
                                        : '${decoder.mediaType} · ${decoder.mediaState}',
                                    color: decoder.standby ? AppColors.warning : AppColors.success,
                                    showDot: true,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      decoder.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                decoder.standby
                                    ? s.t('Decoder in Standby', 'Décodeur en veille')
                                    : '${decoder.channelNumber}. ${decoder.channelName}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              if (!decoder.standby && decoder.currentProgram.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  decoder.currentProgram,
                                  style: TextStyle(fontSize: 13.5, color: context.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Channel Zapping
                SectionCard(
                  title: s.t('Quick Channel Zap', 'Zapping rapide'),
                  subtitle: s.t('Click any channel to tune decoder immediately', 'Cliquez sur une chaîne pour zapper'),
                  icon: Icons.bolt_rounded,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quickChannels.map((ch) {
                      final isCurrent = !decoder.standby && decoder.channelNumber == ch.num;
                      return ActionChip(
                        avatar: CircleAvatar(
                          backgroundColor: isCurrent ? AppColors.orange : context.subtleSurface,
                          foregroundColor: isCurrent ? Colors.white : null,
                          child: Text('${ch.num}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        label: Text(ch.name),
                        side: BorderSide(
                          color: isCurrent ? AppColors.orange : context.borderColor,
                        ),
                        onPressed: () => c.zapTvChannel(decoder.key, ch.num, ch.name),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Decoder Specs
                SectionCard(
                  title: s.t('Decoder Information', 'Informations du décodeur'),
                  icon: Icons.info_outline_rounded,
                  child: Column(
                    children: [
                      InfoRow(label: s.t('Model', 'Modèle'), value: decoder.model),
                      InfoRow(label: 'IP Address', value: decoder.ipAddress, mono: true, copyable: true),
                      InfoRow(label: 'MAC Address', value: decoder.key, mono: true, copyable: true),
                      InfoRow(label: 'Control API', value: 'http://${decoder.ipAddress}:8080/remoteControl/cmd', mono: true),
                    ],
                  ),
                ),
              ],
            );

          final remoteWidget = SizedBox(
            width: 300,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RemoteBtn(
                          icon: Icons.power_settings_new_rounded,
                          accent: AppColors.danger,
                          tooltip: 'Power',
                          onTap: () => c.sendTvRemoteKey(decoder.key, kPower),
                        ),
                        Text(
                          'ORANGE TV',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: context.textSecondary,
                          ),
                        ),
                        _RemoteBtn(
                          icon: Icons.volume_off_rounded,
                          tooltip: 'Mute',
                          onTap: () => c.sendTvRemoteKey(decoder.key, kMute),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Number Pad 1..9, 0
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.75,
                      children: [
                        for (int n = 1; n <= 9; n++)
                          _RemoteTextBtn(
                            label: '$n',
                            onTap: () => c.sendTvRemoteKey(decoder.key, 512 + n),
                          ),
                        _RemoteTextBtn(
                          label: 'BACK',
                          small: true,
                          onTap: () => c.sendTvRemoteKey(decoder.key, kBack),
                        ),
                        _RemoteTextBtn(
                          label: '0',
                          onTap: () => c.sendTvRemoteKey(decoder.key, 512),
                        ),
                        _RemoteTextBtn(
                          label: 'MENU',
                          small: true,
                          accent: AppColors.orange,
                          onTap: () => c.sendTvRemoteKey(decoder.key, kMenu),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Circular D-Pad + OK
                    Container(
                      width: 176,
                      height: 176,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.subtleSurface,
                        border: Border.all(color: context.borderColor, width: 1.5),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 8,
                            child: IconButton(
                              onPressed: () => c.sendTvRemoteKey(decoder.key, kUp),
                              icon: const Icon(Icons.keyboard_arrow_up_rounded),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            child: IconButton(
                              onPressed: () => c.sendTvRemoteKey(decoder.key, kDown),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            child: IconButton(
                              onPressed: () => c.sendTvRemoteKey(decoder.key, kLeft),
                              icon: const Icon(Icons.keyboard_arrow_left_rounded),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            child: IconButton(
                              onPressed: () => c.sendTvRemoteKey(decoder.key, kRight),
                              icon: const Icon(Icons.keyboard_arrow_right_rounded),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              minimumSize: const Size(58, 58),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => c.sendTvRemoteKey(decoder.key, kOk),
                            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Vol & Channel rockers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RockerPill(
                          topLabel: 'VOL +',
                          bottomLabel: 'VOL −',
                          onTop: () => c.sendTvRemoteKey(decoder.key, kVolUp),
                          onBottom: () => c.sendTvRemoteKey(decoder.key, kVolDown),
                        ),
                        _RockerPill(
                          topLabel: 'CH +',
                          bottomLabel: 'CH −',
                          onTop: () => c.sendTvRemoteKey(decoder.key, kChUp),
                          onBottom: () => c.sendTvRemoteKey(decoder.key, kChDown),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Media transport bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RemoteBtn(
                          icon: Icons.fast_rewind_rounded,
                          tooltip: 'Rewind',
                          onTap: () => c.sendTvRemoteKey(decoder.key, kRew),
                        ),
                        _RemoteBtn(
                          icon: Icons.play_arrow_rounded,
                          accent: AppColors.orange,
                          tooltip: 'Play / Pause',
                          onTap: () => c.sendTvRemoteKey(decoder.key, kPlay),
                        ),
                        _RemoteBtn(
                          icon: Icons.fast_forward_rounded,
                          tooltip: 'Fast Forward',
                          onTap: () => c.sendTvRemoteKey(decoder.key, kFfwd),
                        ),
                        _RemoteBtn(
                          icon: Icons.fiber_manual_record_rounded,
                          accent: AppColors.danger,
                          tooltip: 'Record',
                          onTap: () => c.sendTvRemoteKey(decoder.key, kRec),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: infoColumn),
                const SizedBox(width: 20),
                remoteWidget,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              infoColumn,
              const SizedBox(height: 20),
              Center(child: remoteWidget),
            ],
          );
        },
      ),
    );
  }
}

class _RemoteBtn extends StatelessWidget {
  final IconData icon;
  final Color? accent;
  final String tooltip;
  final VoidCallback onTap;

  const _RemoteBtn({
    required this.icon,
    this.accent,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (accent ?? context.textSecondary).withValues(alpha: 0.14),
            border: Border.all(
              color: (accent ?? context.borderColor).withValues(alpha: 0.45),
            ),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
      ),
    );
  }
}

class _RemoteTextBtn extends StatelessWidget {
  final String label;
  final bool small;
  final Color? accent;
  final VoidCallback onTap;

  const _RemoteTextBtn({
    required this.label,
    this.small = false,
    this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent != null
              ? accent!.withValues(alpha: 0.16)
              : context.subtleSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent?.withValues(alpha: 0.45) ?? context.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 10.5 : 14,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _RockerPill extends StatelessWidget {
  final String topLabel;
  final String bottomLabel;
  final VoidCallback onTop;
  final VoidCallback onBottom;

  const _RockerPill({
    required this.topLabel,
    required this.bottomLabel,
    required this.onTop,
    required this.onBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: context.subtleSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: onTop,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: Text(topLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Divider(height: 1, color: context.borderColor),
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            onTap: onBottom,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: Text(bottomLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
