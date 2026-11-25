import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class GraphsScreen extends StatefulWidget {
  final AppController controller;
  const GraphsScreen({super.key, required this.controller});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  String? _selectedKey;
  bool _showDown = true;
  bool _showUp = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final interfaces = c.interfaces;
    if (interfaces.isEmpty) {
      return EmptyStateView(
        icon: Icons.show_chart_rounded,
        title: s.t('No interfaces available', 'Aucune interface disponible'),
      );
    }

    final selectedIntf = interfaces.where((i) => i.key == _selectedKey).firstOrNull ??
        interfaces.first;
    final samples = c.trafficHistory[selectedIntf.key] ?? const <TrafficSample>[];

    double curDown = samples.isNotEmpty ? samples.last.downMbps : 0;
    double curUp = samples.isNotEmpty ? samples.last.upMbps : 0;
    double peakDown = samples.isNotEmpty
        ? samples.map((e) => e.downMbps).reduce(max)
        : 0;
    double peakUp = samples.isNotEmpty
        ? samples.map((e) => e.upMbps).reduce(max)
        : 0;
    double avgDown = samples.isNotEmpty
        ? samples.map((e) => e.downMbps).reduce((a, b) => a + b) / samples.length
        : 0;
    double avgUp = samples.isNotEmpty
        ? samples.map((e) => e.upMbps).reduce((a, b) => a + b) / samples.length
        : 0;

    final maxY = max(
      10.0,
      max(_showDown ? peakDown : 0.0, _showUp ? peakUp : 0.0) * 1.2,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Interface selector bar
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    s.t('Interface:', 'Interface :'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  ...interfaces.map((i) => ChoiceChip(
                        avatar: Icon(
                          i.type == 'wan'
                              ? Icons.public_rounded
                              : (i.type == 'wif' || i.type == 'gwi')
                                  ? Icons.wifi_rounded
                                  : Icons.settings_ethernet_rounded,
                          size: 15,
                        ),
                        label: Text(i.name),
                        selected: i.key == selectedIntf.key,
                        onSelected: (_) => setState(() => _selectedKey = i.key),
                      )),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(s.t('Download', 'Descendant')),
                    selected: _showDown,
                    selectedColor: AppColors.info.withValues(alpha: 0.2),
                    onSelected: (v) => setState(() => _showDown = v),
                  ),
                  FilterChip(
                    label: Text(s.t('Upload', 'Montant')),
                    selected: _showUp,
                    selectedColor: AppColors.purple.withValues(alpha: 0.2),
                    onSelected: (v) => setState(() => _showUp = v),
                  ),
                  OutlinedButton.icon(
                    onPressed: c.togglePollingPaused,
                    icon: Icon(
                      c.pollingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 16,
                    ),
                    label: Text(
                      c.pollingPaused ? s.t('Resume', 'Reprendre') : s.t('Pause', 'Pause'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live KPI summary row
          LayoutBuilder(
            builder: (ctx, box) {
              final cols = box.maxWidth > 900 ? 4 : 2;
              final w = (box.maxWidth - (cols - 1) * 14) / cols;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      title: s.t('Current Download', 'Débit Descendant'),
                      value: '${curDown.toStringAsFixed(1)} Mbps',
                      subtitle: '${s.t("Average", "Moyenne")}: ${avgDown.toStringAsFixed(1)} Mbps',
                      icon: Icons.south_rounded,
                      accentColor: AppColors.info,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      title: s.t('Peak Download', 'Pic Descendant'),
                      value: '${peakDown.toStringAsFixed(1)} Mbps',
                      subtitle: '${samples.length} ${s.t("samples", "mesures")}',
                      icon: Icons.trending_up_rounded,
                      accentColor: AppColors.teal,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      title: s.t('Current Upload', 'Débit Montant'),
                      value: '${curUp.toStringAsFixed(1)} Mbps',
                      subtitle: '${s.t("Average", "Moyenne")}: ${avgUp.toStringAsFixed(1)} Mbps',
                      icon: Icons.north_rounded,
                      accentColor: AppColors.purple,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: KpiCard(
                      title: s.t('Peak Upload', 'Pic Montant'),
                      value: '${peakUp.toStringAsFixed(1)} Mbps',
                      subtitle: selectedIntf.name,
                      icon: Icons.bolt_rounded,
                      accentColor: AppColors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Interactive Multi-Series Area Chart
          SectionCard(
            title: '${selectedIntf.name} · ${s.t("Real-Time Bandwidth", "Bande passante temps réel")}',
            subtitle: s.t(
              'Hover chart for exact timestamped Down/Up rates (Mbps)',
              'Survolez le graphique pour les débits exacts (Mbps)',
            ),
            icon: Icons.area_chart_rounded,
            actions: [
              StatusPill(
                label: c.pollingPaused
                    ? s.t('Paused', 'En pause')
                    : s.t('Live · 2s', 'Direct · 2s'),
                color: c.pollingPaused ? AppColors.warning : AppColors.success,
                showDot: true,
              ),
            ],
            child: SizedBox(
              height: 340,
              child: samples.length < 2
                  ? Center(
                      child: Text(
                        s.t('Waiting for telemetry samples...', 'En attente de mesures...'),
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: context.borderColor.withValues(alpha: 0.6),
                            strokeWidth: 0.8,
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: context.borderColor.withValues(alpha: 0.35),
                            strokeWidth: 0.8,
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(color: context.borderColor),
                            left: BorderSide(color: context.borderColor),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (val, _) => Text(
                                '${val.toStringAsFixed(0)} M',
                                style: AppTheme.monoStyle.copyWith(
                                  fontSize: 10.5,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: max(1, (samples.length / 6).floor()).toDouble(),
                              getTitlesWidget: (val, _) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= samples.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    Formatters.timeHms(samples[idx].timestamp),
                                    style: AppTheme.monoStyle.copyWith(
                                      fontSize: 10,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => context.isDark
                                ? AppColors.darkElevated
                                : AppColors.lightCard,
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final isDown = spot.bar.color == AppColors.info;
                                final idx = spot.x.toInt().clamp(0, samples.length - 1);
                                final ts = Formatters.timeHms(samples[idx].timestamp);
                                return LineTooltipItem(
                                  '${isDown ? "↓ Down" : "↑ Up"}: ${spot.y.toStringAsFixed(1)} Mbps\n$ts',
                                  TextStyle(
                                    color: spot.bar.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          if (_showDown)
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < samples.length; i++)
                                  FlSpot(i.toDouble(), samples[i].downMbps),
                              ],
                              isCurved: true,
                              curveSmoothness: 0.25,
                              color: AppColors.info,
                              barWidth: 2.6,
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
                          if (_showUp)
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < samples.length; i++)
                                  FlSpot(i.toDouble(), samples[i].upMbps),
                              ],
                              isCurved: true,
                              curveSmoothness: 0.25,
                              color: AppColors.purple,
                              barWidth: 2.2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.purple.withValues(alpha: 0.22),
                                    AppColors.purple.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 220),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
