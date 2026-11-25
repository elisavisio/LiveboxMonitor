enum AppLanguage { en, fr }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isFr => lang == AppLanguage.fr;

  String t(String en, String fr) => isFr ? fr : en;

  // Navigation
  String get navOverview => t('Overview & Info', 'Aperçu & Infos');
  String get navDevices => t('Devices', 'Équipements');
  String get navGraphs => t('Traffic Graphs', 'Graphiques');
  String get navEvents => t('Events', 'Événements');
  String get navDhcp => t('DHCP', 'DHCP');
  String get navNatPat => t('NAT / PAT', 'NAT / PAT');
  String get navFirewall => t('Firewall', 'Pare-feu');
  String get navPhone => t('Phone / VoIP', 'Téléphone');
  String get navRepeaters => t('Repeaters', 'Répéteurs');
  String get navTvDecoders => t('TV Decoders', 'Décodeurs TV');
  String get navActions => t('Actions & Tools', 'Actions & Outils');

  String get secMonitoring => t('MONITORING', 'SUPERVISION');
  String get secNetwork => t('NETWORK & SECURITY', 'RÉSEAU & SÉCURITÉ');
  String get secServices => t('SERVICES & HARDWARE', 'SERVICES & MATÉRIEL');
  String get secAdmin => t('ADMINISTRATION', 'ADMINISTRATION');

  // Common
  String get refresh => t('Refresh', 'Actualiser');
  String get save => t('Save', 'Enregistrer');
  String get cancel => t('Cancel', 'Annuler');
  String get delete => t('Delete', 'Supprimer');
  String get add => t('Add', 'Ajouter');
  String get edit => t('Edit', 'Modifier');
  String get close => t('Close', 'Fermer');
  String get apply => t('Apply', 'Appliquer');
  String get search => t('Search...', 'Rechercher...');
  String get online => t('Online', 'En ligne');
  String get offline => t('Offline', 'Hors ligne');
  String get active => t('Active', 'Actif');
  String get inactive => t('Inactive', 'Inactif');
  String get enabled => t('Enabled', 'Activé');
  String get disabled => t('Disabled', 'Désactivé');
  String get demoMode => t('Demo Mode', 'Mode Démo');
  String get liveMode => t('Live Connected', 'Connecté');
  String get signOut => t('Disconnect', 'Déconnexion');
  String get exportCsv => t('Export CSV', 'Exporter CSV');
  String get confirm => t('Confirm', 'Confirmer');
}
