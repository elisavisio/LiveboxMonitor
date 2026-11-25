import 'package:material_ui/material_ui.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  bool _obscurePassword = true;
  bool _savePassword = true;
  String? _loadedProfileId;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _userCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _syncFromActiveProfile();
  }

  void _syncFromActiveProfile() {
    final p = widget.controller.activeProfile;
    if (_loadedProfileId == p.id) return;
    _loadedProfileId = p.id;
    _urlCtrl.text = p.url;
    _userCtrl.text = p.username;
    _passCtrl.text = p.password;
    _savePassword = p.savePassword;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectLive() async {
    final profile = widget.controller.activeProfile.copyWith(
      url: _urlCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      savePassword: _savePassword,
    );
    await widget.controller.upsertProfile(profile);
    await widget.controller.connectLive(
      url: profile.url,
      username: profile.username,
      password: _passCtrl.text,
      profileName: profile.name,
    );
  }

  Future<void> _showAddProfileDialog() async {
    final s = widget.controller.strings;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'http://192.168.1.1/');
    final userCtrl = TextEditingController(text: 'admin');

    final created = await showDialog<ConnectionProfile>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('New Livebox Profile', 'Nouveau profil Livebox')),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: s.t('Profile Name', 'Nom du profil'),
                  hintText: 'Office Livebox 7',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Livebox URL',
                  hintText: 'http://livebox.home/',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userCtrl,
                decoration: InputDecoration(
                  labelText: s.t('Username', 'Identifiant'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                ConnectionProfile(
                  id: 'prof_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  url: urlCtrl.text.trim(),
                  username: userCtrl.text.trim().isEmpty ? 'admin' : userCtrl.text.trim(),
                ),
              );
            },
            child: Text(s.add),
          ),
        ],
      ),
    );

    if (created != null) {
      await widget.controller.upsertProfile(created);
      setState(() => _syncFromActiveProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        _syncFromActiveProfile();
        final c = widget.controller;
        final s = c.strings;

        return Scaffold(
          body: Stack(
            children: [
              // Subtle ambient orange radial glow in corner
              Positioned(
                top: -140,
                left: -120,
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.orange.withValues(alpha: context.isDark ? 0.16 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Top-right quick theme & language toggles
              Positioned(
                top: 20,
                right: 24,
                child: Row(
                  children: [
                    SegmentedButton<AppLanguage>(
                      segments: const [
                        ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                        ButtonSegment(value: AppLanguage.fr, label: Text('FR')),
                      ],
                      selected: {c.language},
                      onSelectionChanged: (v) => c.setLanguage(v.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      tooltip: s.t('Toggle Theme', 'Changer le thème'),
                      onPressed: c.toggleTheme,
                      icon: Icon(
                        c.themeMode == ThemeMode.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              // Center Split Card
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Brand Panel
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(34),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: context.isDark
                                        ? const [Color(0xFF1E1814), Color(0xFF141925)]
                                        : const [Color(0xFFFFF4EC), Color(0xFFF3F6FB)],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.asset(
                                            'assets/icons/app_icon.png',
                                            width: 44,
                                            height: 44,
                                            errorBuilder: (_, _, _) => Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppColors.orange,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(Icons.router_rounded,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Livebox Monitor',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              Text(
                                                'Flutter Desktop · v1.7.4',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: context.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 28),
                                    Text(
                                      s.t(
                                        'Complete telemetry & control for Orange Livebox routers.',
                                        'Supervision et contrôle complets pour votre Livebox Orange.',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      s.t(
                                        'Compatible with Livebox 4, 5, 6, 7, W7, S & Pro, Wi-Fi Repeaters, and Orange TV Decoders.',
                                        'Compatible Livebox 4, 5, 6, 7, W7, S & Pro, Répéteurs Wi-Fi et Décodeurs TV Orange.',
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _FeatureBullet(
                                      icon: Icons.speed_rounded,
                                      text: s.t(
                                        'Real-time fiber ONT optical metrics & traffic graphs',
                                        'Métriques optiques Fibre ONT et graphiques en temps réel',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _FeatureBullet(
                                      icon: Icons.devices_rounded,
                                      text: s.t(
                                        'Device inspector, Wake-on-LAN, DHCP & Firewall rules',
                                        'Inspecteur d\'équipements, Wake-on-LAN, DHCP et Pare-feu',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _FeatureBullet(
                                      icon: Icons.tv_rounded,
                                      text: s.t(
                                        'Virtual TV remote, VoIP call log & raw Sysbus API explorer',
                                        'Télécommande TV, journal d\'appels VoIP et explorateur d\'API',
                                      ),
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 24),
                                    const StatusPill(
                                      label: 'Pure Dart · Direct LAN Sysbus API',
                                      color: AppColors.orange,
                                      icon: Icons.bolt_rounded,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            VerticalDivider(width: 1, color: context.borderColor),
                            // Right Sign-In Form
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.all(34),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      s.t('Connect to Livebox', 'Connexion à la Livebox'),
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.t(
                                        'Select a profile or try the interactive Demo Mode.',
                                        'Sélectionnez un profil ou lancez le Mode Démo interactif.',
                                      ),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Profile selector row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: c.activeProfile.id,
                                            decoration: InputDecoration(
                                              labelText: s.t('Profile', 'Profil'),
                                              prefixIcon: const Icon(Icons.bookmark_outline_rounded, size: 18),
                                            ),
                                            items: c.profiles
                                                .map((p) => DropdownMenuItem(
                                                      value: p.id,
                                                      child: Text(p.name),
                                                    ))
                                                .toList(),
                                            onChanged: (id) {
                                              if (id != null) {
                                                c.selectProfile(id);
                                                setState(() => _syncFromActiveProfile());
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.outlined(
                                          tooltip: s.t('Add profile', 'Ajouter un profil'),
                                          onPressed: _showAddProfileDialog,
                                          icon: const Icon(Icons.add_rounded, size: 18),
                                        ),
                                        if (c.profiles.length > 1) ...[
                                          const SizedBox(width: 6),
                                          IconButton.outlined(
                                            tooltip: s.delete,
                                            onPressed: () async {
                                              await c.deleteProfile(c.activeProfile.id);
                                              setState(() => _syncFromActiveProfile());
                                            },
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _urlCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Livebox URL',
                                        hintText: 'http://livebox.home/ or http://192.168.1.1/',
                                        prefixIcon: Icon(Icons.link_rounded, size: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _userCtrl,
                                      decoration: InputDecoration(
                                        labelText: s.t('Username', 'Identifiant'),
                                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _passCtrl,
                                      obscureText: _obscurePassword,
                                      onSubmitted: (_) => _connectLive(),
                                      decoration: InputDecoration(
                                        labelText: s.t('Admin Password', 'Mot de passe administrateur'),
                                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _savePassword,
                                          onChanged: (v) =>
                                              setState(() => _savePassword = v ?? true),
                                        ),
                                        Text(
                                          s.t('Remember password locally', 'Mémoriser le mot de passe'),
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                    if (c.connectionError != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppColors.danger.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline_rounded,
                                                color: AppColors.danger, size: 18),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                c.connectionError!,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: AppColors.danger,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: c.isConnecting ? null : _connectLive,
                                      icon: c.isConnecting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.login_rounded, size: 18),
                                      label: Text(
                                        c.isConnecting
                                            ? s.t('Connecting...', 'Connexion...')
                                            : s.t('Connect to Livebox', 'Se connecter à la Livebox'),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: Divider(color: context.borderColor)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(
                                            s.t('OR', 'OU'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Expanded(child: Divider(color: context.borderColor)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: c.isConnecting ? null : c.connectDemo,
                                      icon: const Icon(Icons.play_circle_outline_rounded,
                                          size: 18, color: AppColors.orange),
                                      label: Text(
                                        s.t(
                                          'Launch Interactive Demo Mode (Livebox 7 W7)',
                                          'Lancer le Mode Démo Interactif (Livebox 7 W7)',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, height: 1.35),
          ),
        ),
      ],
    );
  }
}
