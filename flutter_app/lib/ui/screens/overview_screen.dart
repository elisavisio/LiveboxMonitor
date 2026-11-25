import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class OverviewScreen extends StatelessWidget {
  final AppController controller;
  final VoidCallback onOpenGraphs;
  final VoidCallback onOpenDevices;

  const OverviewScreen({
    super.key,
    required this.controller,
    required this.onOpenGraphs,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final info = controller.info;
    if (info == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeDevices = controller.devices.where((d) => d.isActiveWithIp).length;
    final totalDevices = controller.devices.length;
    final latestWan = controller.latestWanTraffic;
    final wanKey = controller.interfaces
        .where((i) => i.type == 'wan')
        .map((e) => e.key)
        .firstOrNull;
    final wanSeries = wanKey != null ? (controller.trafficHistory[wanKey] ?? []) : <TrafficSample>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top 4 KPI Hero Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1020
                  ? 4
                  : constraints.maxWidth > 640
                      ? 2
                      : 1;
              final cardWidth = (constraints.maxWidth - (cols - 1) * 14) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: KpiCard(
                      title: s.t('WAN / Fiber Status', 'Statut WAN / Fibre'),
                      value: info.wanStatus.toUpperCase() == 'UP' ? s.online : s.offline,
                      subtitle: '${info.linkType} · ${info.wanIpv4}',
                      icon: Icons.public_rounded,
                      accentColor: info.wanStatus.toUpperCase() == 'UP'
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onOpenDevices,
                      child: KpiCard(
                        title: s.t('Connected Devices', 'Équipements actifs'),
                        value: '$activeDevices / $totalDevices',
                        subtitle: s.t(
                          '${controller.repeaters.length} repeaters · ${controller.tvDecoders.length} TV',
                          '${controller.repeaters.length} répéteurs · ${controller.tvDecoders.length} TV',
                        ),
                        icon: Icons.devices_rounded,
                        accentColor: AppColors.orange,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onOpenGraphs,
                      child: KpiCard(
                        title: s.t('Live Throughput', 'Débit en temps réel'),
                        value: latestWan != null
                            ? '↓ ${latestWan.downMbps.toStringAsFixed(1)} Mbps'
                            : '—',
                        subtitle: latestWan != null
                            ? '↑ ${latestWan.upMbps.toStringAsFixed(1)} Mbps'
                            : s.t('Sampling...', 'Mesure...'),
                        icon: Icons.swap_vert_rounded,
                        accentColor: AppColors.info,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: KpiCard(
                      title: s.t('Uptime & Memory', 'Disponibilité & RAM'),
                      value: Formatters.duration(info.uptimeSeconds),
                      subtitle:
                          'RAM ${(info.memoryUsedPercent * 100).toStringAsFixed(0)}% · ${Formatters.bytes((info.memoryTotalKb - info.memoryFreeKb) * 1024)}',
                      icon: Icons.memory_rounded,
                      accentColor: AppColors.purple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Live Mini Traffic Sparkline + Quick Services
          ResponsiveRow(
            leftFlex: 3,
            rightFlex: 2,
            breakpoint: 840,
            left: SectionCard(
                  title: s.t('WAN Live Traffic', 'Trafic WAN en direct'),
                  subtitle: s.t(
                    'Download (Blue) & Upload (Purple) · Mbps',
                    'Descendant (Bleu) & Montant (Violet) · Mbps',
                  ),
                  icon: Icons.show_chart_rounded,
                  actions: [
                    TextButton.icon(
                      onPressed: onOpenGraphs,
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: Text(s.t('Full Graphs', 'Graphiques complets')),
                    ),
                  ],
                  child: SizedBox(
                    height: 175,
                    child: wanSeries.length < 2
                        ? Center(
                            child: Text(
                              s.t('Collecting traffic samples...', 'Collecte des mesures...'),
                              style: TextStyle(color: context.textSecondary),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (v) => FlLine(
                                  color: context.borderColor.withValues(alpha: 0.6),
                                  strokeWidth: 0.8,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    getTitlesWidget: (val, _) => Text(
                                      val.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < wanSeries.length; i++)
                                      FlSpot(i.toDouble(), wanSeries[i].downMbps),
                                  ],
                                  isCurved: true,
                                  color: AppColors.info,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.info.withValues(alpha: 0.28),
                                        AppColors.info.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                                LineChartBarData(
                                  spots: [
                                    for (int i = 0; i < wanSeries.length; i++)
                                      FlSpot(i.toDouble(), wanSeries[i].upMbps),
                                  ],
                                  isCurved: true,
                                  color: AppColors.purple,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.purple.withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(milliseconds: 220),
                          ),
              ),
            ),
            right: SectionCard(
                  title: s.t('Active Services', 'Services actifs'),
                  subtitle: info.modelName,
                  icon: Icons.widgets_rounded,
                  child: Column(
                    children: [
                      _ServiceSwitchTile(
                        icon: Icons.wifi_rounded,
                        title: 'Wi-Fi',
                        subtitle: info.wifiEnabled
                            ? s.t('Radios broadcasting', 'Réseaux actifs')
                            : s.disabled,
                        value: info.wifiEnabled,
                        onChanged: (v) => controller.setGlobalWifi(v),
                      ),
                      Divider(height: 1, color: context.borderColor),
                      _ServiceSwitchTile(
                        icon: Icons.people_outline_rounded,
                        title: s.t('Guest Wi-Fi', 'Wi-Fi Invité'),
                        subtitle: info.guestWifiEnabled ? s.active : s.disabled,
                        value: info.guestWifiEnabled,
                        onChanged: (v) => controller.setGuestWifi(v, timerHours: v ? 4 : 0),
                      ),
                      Divider(height: 1, color: context.borderColor),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_in_talk_rounded,
                            size: 19, color: AppColors.success),
                        title: const Text('VoIP / Telephony', style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          info.voipNumber.isNotEmpty ? info.voipNumber : s.online,
                          style: AppTheme.monoStyle.copyWith(fontSize: 11.5),
                        ),
                        trailing: StatusPill(
                          label: info.voipRegistered ? s.online : s.offline,
                          color: info.voipRegistered ? AppColors.success : AppColors.danger,
                          showDot: true,
                        ),
                      ),
                      Divider(height: 1, color: context.borderColor),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.live_tv_rounded,
                            size: 19, color: AppColors.orange),
                        title: const Text('Orange IPTV', style: TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${controller.tvDecoders.length} ${s.t("decoder(s)", "décodeur(s)")}',
                          style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                        ),
                        trailing: StatusPill(
                          label: info.iptvEnabled ? s.enabled : s.disabled,
                          color: info.iptvEnabled ? AppColors.success : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 18),

          // System, WAN/LAN, and Fiber ONT Details
          ResponsiveRow(
            breakpoint: 840,
            left: SectionCard(
                  title: s.t('Livebox Hardware & Firmware', 'Matériel & Firmware Livebox'),
                  icon: Icons.router_rounded,
                  child: Column(
                    children: [
                      InfoRow(label: s.t('Model', 'Modèle'), value: '${info.modelName} (${info.productClass})'),
                      InfoRow(label: s.t('Manufacturer', 'Fabricant'), value: info.manufacturer),
                      InfoRow(label: s.t('Serial Number', 'Numéro de série'), value: info.serialNumber, mono: true, copyable: true),
                      InfoRow(label: s.t('Base MAC', 'Adresse MAC'), value: info.macAddress, mono: true, copyable: true),
                      InfoRow(label: s.t('Hardware Version', 'Version matérielle'), value: info.hardwareVersion, mono: true),
                      InfoRow(label: s.t('Software Version', 'Version logicielle'), value: info.softwareVersion, mono: true, copyable: true),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            s.t('Memory Usage', 'Utilisation RAM'),
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                          const Spacer(),
                          Text(
                            '${(info.memoryUsedPercent * 100).toStringAsFixed(1)}%',
                            style: AppTheme.monoStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: info.memoryUsedPercent,
                          minHeight: 7,
                          backgroundColor: context.subtleSurface,
                          color: info.memoryUsedPercent > 0.85 ? AppColors.danger : AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            right: SectionCard(
                  title: s.t('WAN, IPv6 & Fiber ONT', 'WAN, IPv6 & Optique ONT'),
                  icon: Icons.settings_ethernet_rounded,
                  iconColor: AppColors.info,
                  child: Column(
                    children: [
                      InfoRow(label: 'WAN IPv4', value: info.wanIpv4, mono: true, copyable: true),
                      InfoRow(label: 'WAN IPv6', value: info.wanIpv6, mono: true, copyable: true),
                      InfoRow(label: 'IPv6 Prefix', value: info.wanIpv6Prefix, mono: true, copyable: true),
                      InfoRow(label: s.t('Gateway', 'Passerelle'), value: info.wanGateway, mono: true),
                      InfoRow(label: 'DNS', value: info.dnsServers.join(', '), mono: true),
                      InfoRow(label: 'LAN IP / Mask', value: '${info.lanIp} / ${info.lanMask}', mono: true),
                      if (info.opticalRxPowerDbm != null) ...[
                        Divider(height: 16, color: context.borderColor),
                        InfoRow(
                          label: s.t('ONT Optical Rx', 'Puissance Optique Rx'),
                          value: '${info.opticalRxPowerDbm!.toStringAsFixed(2)} dBm',
                          mono: true,
                          valueColor: info.opticalRxPowerDbm! > -24
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        if (info.opticalTxPowerDbm != null)
                          InfoRow(
                            label: s.t('ONT Optical Tx', 'Puissance Optique Tx'),
                            value: '${info.opticalTxPowerDbm!.toStringAsFixed(2)} dBm',
                            mono: true,
                          ),
                        if (info.opticalTempC != null)
                          InfoRow(
                            label: s.t('ONT Temperature', 'Température ONT'),
                            value: '${info.opticalTempC!.toStringAsFixed(1)} °C · ${info.opticalVoltageV?.toStringAsFixed(2) ?? "—"} V',
                            mono: true,
                          ),
                      ],
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 18),

          // Interfaces Table
          SectionCard(
            title: s.t('Network Interfaces', 'Interfaces Réseau'),
            subtitle: s.t(
              'Live link status, speeds, and cumulative byte counters',
              'État des liens, vitesses et compteurs cumulés',
            ),
            icon: Icons.cable_rounded,
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 820),
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(s.t('Interface', 'Interface'))),
                    DataColumn(label: Text(s.t('Key', 'Clé'))),
                    DataColumn(label: Text(s.t('Status', 'Statut'))),
                    DataColumn(label: Text(s.t('Speed / Band', 'Vitesse / Bande'))),
                    DataColumn(label: Text(s.t('Live Rx', 'Rx Direct')), numeric: true),
                    DataColumn(label: Text(s.t('Live Tx', 'Tx Direct')), numeric: true),
                    DataColumn(label: Text(s.t('Total Rx', 'Total Rx')), numeric: true),
                    DataColumn(label: Text(s.t('Total Tx', 'Total Tx')), numeric: true),
                  ],
                  rows: controller.interfaces.map((i) {
                    return DataRow(cells: [
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            i.type == 'wan'
                                ? Icons.public_rounded
                                : (i.type == 'wif' || i.type == 'gwi')
                                    ? Icons.wifi_rounded
                                    : Icons.settings_ethernet_rounded,
                            size: 16,
                            color: i.up ? AppColors.orange : context.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      )),
                      DataCell(Text(i.key, style: AppTheme.monoStyle.copyWith(fontSize: 12))),
                      DataCell(StatusPill(
                        label: i.up ? 'UP' : 'DOWN',
                        color: i.up ? AppColors.success : context.textSecondary,
                        showDot: true,
                      )),
                      DataCell(Text(
                        i.band != null
                            ? '${i.band} · Ch ${i.channel ?? "Auto"}'
                            : (i.speedMbps > 0 ? '${i.speedMbps} Mbps' : '—'),
                        style: const TextStyle(fontSize: 12.5),
                      )),
                      DataCell(Text(
                        Formatters.bytesPerSecAsBitrate(i.rxBytesPerSec),
                        style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppColors.info),
                      )),
                      DataCell(Text(
                        Formatters.bytesPerSecAsBitrate(i.txBytesPerSec),
                        style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppColors.purple),
                      )),
                      DataCell(Text(Formatters.bytes(i.rxBytes),
                          style: AppTheme.monoStyle.copyWith(fontSize: 12))),
                      DataCell(Text(Formatters.bytes(i.txBytes),
                          style: AppTheme.monoStyle.copyWith(fontSize: 12))),
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

class _ServiceSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ServiceSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 19, color: value ? AppColors.orange : context.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
