# Livebox Monitor Server (Dart Frog + Docker)

Application serveur **strictement en lecture seule** pour superviser votre Livebox Orange en continu dans un conteneur Docker, basée sur **Dart Frog** et réutilisant la librairie partagée `packages/livebox_client` de l'application Flutter.

## Fonctionnalités

- **Accès strictement en lecture seule (`ReadOnlyLiveboxClient`)** : liste blanche d'appels API en lecture uniquement (`get`, `getWANStatus`, `getStationStats`, `buildTopology`, écoute d'événements). Aucune écriture ni redémarrage possible.
- **Écoute événementielle temps réel** : abonnement continu au canal d'événements Livebox (`Devices.Device`, `HomeLan`) + diffusion temps réel vers l'IHM Web via **Server-Sent Events** (`/api/stream`).
- **Gestion des équipements Connus / Inconnus** : chaque appareil détecté peut être tagué `Connu` ou `Inconnu` avec une note personnalisée, stockée dans SQLite (`/data/livebox_monitor.db`).
- **Graphes de présence et de bande passante** : historique par équipement (1h, 6h, 24h, 7j) de disponibilité (En ligne / Hors ligne) et des débits Descendant / Montant.
- **Carte des équipements & Arbre de connexion** : visualisation SVG interactive et arborescence hiérarchique `Livebox → Répéteurs → Liens Ethernet / Wi-Fi → Équipements`.
- **Alertes Email (SMTP)** : envoi automatique d'un email lorsqu'un nouvel équipement inconnu apparaît sur le réseau.
- **Stockage léger, pérenne et sécurisé** :
  - Base **SQLite (mode WAL)** sur le volume Docker persistant `/data`.
  - **Coffre chiffré AES-256-GCM** (`/data/secrets.enc.json`, `chmod 600`) pour les mots de passe Livebox et SMTP, avec clé maître issue par priorité de :
    1. **Docker Secret** (`/run/secrets/lbm_master_key` ou `LBM_MASTER_KEY_FILE`),
    2. Variable d'environnement `LBM_MASTER_KEY`,
    3. Clé aléatoire 256 bits auto-générée et persistée dans `/data/.master.key` (`chmod 600`).

## Démarrage rapide avec Docker Compose

```bash
cd server
cp .env.example .env
# (Optionnel) Éditez .env ou configurez directement depuis l'IHM Web
docker compose up -d --build
```

Ouvrez ensuite l'IHM Web sur : `http://localhost:8080`

> Par défaut au premier démarrage sans mot de passe Livebox configuré, le serveur démarre en **Mode Démo** pour vous permettre d'explorer l'interface immédiatement. Rendez-vous dans l'onglet **🔐 Configuration** pour saisir l'URL (`http://192.168.1.1/` ou `http://livebox.home/`) et le mot de passe de votre Livebox.

## Tester les alertes email localement (Mailpit)

Un profil optionnel `mail-test` lance un serveur SMTP local **Mailpit** :

```bash
cd server
docker compose --profile mail-test up -d --build
```

1. Dans l'IHM Web → **🔐 Configuration → Alertes Email (SMTP)** :
   - Serveur SMTP : `mailpit`, Port : `1025`
   - Cochez **Activer les notifications** et **Autoriser sans TLS**
   - Expéditeur : `livebox@local`, Destinataire : `admin@local`
   - Cliquez **Enregistrer SMTP**, puis **Envoyer un email de test** (ou **+ Simuler nouvel appareil** en Mode Démo).
2. Consultez les emails reçus dans l'interface Mailpit sur `http://localhost:8025`.

## Développement local (sans Docker)

```bash
cd server
dart pub get
dart_frog dev
```