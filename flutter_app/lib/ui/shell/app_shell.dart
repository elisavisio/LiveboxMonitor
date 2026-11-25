import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_controller.dart';
import '../screens/actions_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/dhcp_screen.dart';
import '../screens/events_screen.dart';
import '../screens/firewall_screen.dart';
import '../screens/graphs_screen.dart';
import '../screens/nat_pat_screen.dart';
import '../screens/overview_screen.dart';
import '../screens/phone_screen.dart';
import '../screens/repeaters_screen.dart';
import '../screens/tv_decoder_screen.dart';
import '../widgets/common_widgets.dart';

enum AppSection {
  overview,
  devices,
  graphs,
  events,
  dhcp,
  natPat,
  firewall,
  phone,
  repeaters,
  tvDecoders,
  actions,
}

class AppShell extends StatefulWidget {
  final AppController controller;
  const AppShell({super.key, required this.controller});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.overview;
  bool _sidebarCollapsed = false;

  String _sectionTitle(AppSection sec, AppStrings s) => switch (sec) {
        AppSection.overview => s.navOverview,
        AppSection.devices => s.navDevices,
        AppSection.graphs => s.navGraphs,
        AppSection.events => s.navEvents,
        AppSection.dhcp => s.navDhcp,
        AppSection.natPat => s.navNatPat,
        AppSection.firewall => s.navFirewall,
        AppSection.phone => s.navPhone,
        AppSection.repeaters => s.navRepeaters,
        AppSection.tvDecoders => s.navTvDecoders,
        AppSection.actions => s.navActions,
      };

  Widget _buildActiveScreen() {
    final c = widget.controller;
    return switch (_section) {
      AppSection.overview => OverviewScreen(
          controller: c,
          onOpenGraphs: () => setState(() => _section = AppSection.graphs),
          onOpenDevices: () => setState(() => _section = AppSection.devices),
        ),
      AppSection.devices => DevicesScreen(controller: c),
      AppSection.graphs => GraphsScreen(controller: c),
      AppSection.events => EventsScreen(controller: c),
      AppSection.dhcp => DhcpScreen(controller: c),
      AppSection.natPat => NatPatScreen(controller: c),
      AppSection.firewall => FirewallScreen(controller: c),
      AppSection.phone => PhoneScreen(controller: c),
      AppSection.repeaters => RepeatersScreen(controller: c),
      AppSection.tvDecoders => TvDecoderScreen(controller: c),
      AppSection.actions => ActionsScreen(controller: c),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final info = c.info;
    final wanSample = c.latestWanTraffic;
    final sidebarWidth = _sidebarCollapsed ? 74.0 : 244.0;

    return Scaffold(
      body: Row(
        children: [
          // Collapsible Sidebar Navigation Rail
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: context.sidebarColor,
              border: Border(right: BorderSide(color: context.borderColor)),
            ),
            child: Column(
              children: [
                // Brand Header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _sidebarCollapsed ? 12 : 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 34,
                          height: 34,
                          errorBuilder: (_, _, _) => Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.router_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      if (!_sidebarCollapsed) ...[
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Livebox Monitor',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                info?.modelName ?? 'Connecting...',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: context.borderColor),

                // Scrollable grouped nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    children: [
                      _NavGroupLabel(label: s.secMonitoring, collapsed: _sidebarCollapsed),
                      _NavItem(
                        icon: Icons.dashboard_rounded,
                        label: s.navOverview,
                        selected: _section == AppSection.overview,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.overview),
                      ),
                      _NavItem(
                        icon: Icons.devices_rounded,
                        label: s.navDevices,
                        badge: '${c.devices.where((d) => d.active).length}',
                        selected: _section == AppSection.devices,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.devices),
                      ),
                      _NavItem(
                        icon: Icons.show_chart_rounded,
                        label: s.navGraphs,
                        selected: _section == AppSection.graphs,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.graphs),
                      ),
                      _NavItem(
                        icon: Icons.notifications_active_outlined,
                        label: s.navEvents,
                        badge: c.events.isNotEmpty ? '${c.events.length}' : null,
                        selected: _section == AppSection.events,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.events),
                      ),
                      const SizedBox(height: 10),
                      _NavGroupLabel(label: s.secNetwork, collapsed: _sidebarCollapsed),
                      _NavItem(
                        icon: Icons.dns_outlined,
                        label: s.navDhcp,
                        selected: _section == AppSection.dhcp,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.dhcp),
                      ),
                      _NavItem(
                        icon: Icons.alt_route_rounded,
                        label: s.navNatPat,
                        selected: _section == AppSection.natPat,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.natPat),
                      ),
                      _NavItem(
                        icon: Icons.shield_outlined,
                        label: s.navFirewall,
                        selected: _section == AppSection.firewall,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.firewall),
                      ),
                      const SizedBox(height: 10),
                      _NavGroupLabel(label: s.secServices, collapsed: _sidebarCollapsed),
                      _NavItem(
                        icon: Icons.phone_in_talk_outlined,
                        label: s.navPhone,
                        selected: _section == AppSection.phone,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.phone),
                      ),
                      _NavItem(
                        icon: Icons.wifi_tethering_rounded,
                        label: s.navRepeaters,
                        badge: c.repeaters.isNotEmpty ? '${c.repeaters.length}' : null,
                        selected: _section == AppSection.repeaters,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.repeaters),
                      ),
                      _NavItem(
                        icon: Icons.tv_rounded,
                        label: s.navTvDecoders,
                        badge: c.tvDecoders.isNotEmpty ? '${c.tvDecoders.length}' : null,
                        selected: _section == AppSection.tvDecoders,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.tvDecoders),
                      ),
                      const SizedBox(height: 10),
                      _NavGroupLabel(label: s.secAdmin, collapsed: _sidebarCollapsed),
                      _NavItem(
                        icon: Icons.tune_rounded,
                        label: s.navActions,
                        selected: _section == AppSection.actions,
                        collapsed: _sidebarCollapsed,
                        onTap: () => setState(() => _section = AppSection.actions),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: context.borderColor),
                // Bottom Footer Controls
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      if (!_sidebarCollapsed)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: c.toggleLanguage,
                                child: Text(c.language == AppLanguage.en ? 'EN / FR' : 'FR / EN',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: s.t('Toggle Theme', 'Changer le thème'),
                              onPressed: c.toggleTheme,
                              icon: Icon(
                                c.themeMode == ThemeMode.dark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton.outlined(
                              tooltip: s.signOut,
                              onPressed: c.disconnect,
                              icon: const Icon(Icons.logout_rounded,
                                  size: 17, color: AppColors.danger),
                            ),
                          ],
                        )
                      else
                        IconButton(
                          tooltip: s.signOut,
                          onPressed: c.disconnect,
                          icon: const Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.danger),
                        ),
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _sidebarCollapsed
                                    ? Icons.keyboard_double_arrow_right_rounded
                                    : Icons.keyboard_double_arrow_left_rounded,
                                size: 16,
                                color: context.textSecondary,
                              ),
                              if (!_sidebarCollapsed) ...[
                                const SizedBox(width: 6),
                                Text(
                                  s.t('Collapse sidebar', 'Réduire'),
                                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Command Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: context.sidebarColor,
                    border: Border(bottom: BorderSide(color: context.borderColor)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _sectionTitle(_section, s),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusPill(
                        label: c.isDemo ? s.demoMode : s.liveMode,
                        color: c.isDemo ? AppColors.orange : AppColors.success,
                        showDot: true,
                      ),
                      const Spacer(),
                      // Live WAN Throughput Pill
                      if (wanSample != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.subtleSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.south_rounded, size: 13, color: AppColors.info),
                              const SizedBox(width: 4),
                              Text(
                                '${wanSample.downMbps.toStringAsFixed(1)} Mbps',
                                style: AppTheme.monoStyle.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.north_rounded, size: 13, color: AppColors.purple),
                              const SizedBox(width: 4),
                              Text(
                                '${wanSample.upMbps.toStringAsFixed(1)} Mbps',
                                style: AppTheme.monoStyle.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: c.isRefreshing ? null : c.refreshAll,
                        icon: c.isRefreshing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(s.refresh),
                      ),
                    ],
                  ),
                ),

                // Active Page Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey(_section),
                      child: _buildActiveScreen(),
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

class _NavGroupLabel extends StatelessWidget {
  final String label;
  final bool collapsed;
  const _NavGroupLabel({required this.label, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    if (collapsed) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.badge,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: selected
          ? AppColors.orange.withValues(alpha: context.isDark ? 0.18 : 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 9.5,
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? AppColors.orange : context.textSecondary,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.orange : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.orange.withValues(alpha: 0.25)
                          : context.subtleSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: AppTheme.monoStyle.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.orange : context.textSecondary,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: collapsed ? Tooltip(message: label, child: child) : child,
    );
  }
}
