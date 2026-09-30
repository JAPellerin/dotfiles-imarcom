## Why

L'utilisateur travaille au quotidien dans **Orca** (`stablyai/orca`, licence MIT), un environnement qui lance plusieurs agents de code en parallèle, chacun dans son worktree : c'est l'outil avec lequel il mène plusieurs changes à la fois. Il l'utilise aujourd'hui sous Windows ; le poste Ubuntu doit l'avoir d'office (demande du 30 sept 2026, vague 6).

## What Changes

- Nouveau module **`orca`** (53, groupe `apps`, dépend de `base`, nécessite une session graphique) : le `.deb` officiel le plus récent des releases GitHub de `stablyai/orca` (paquet `orca-ide`), par les helpers du socle ; rien de retéléchargé si le paquet est là ; les mises à jour restent à l'application.
- **Profil AppArmor** versionné (`config/orca/apparmor-profile`), déployé dans `/etc/apparmor.d/` et chargé, comme pour Rocket.Chat : sans lui, Ubuntu 26.04 refuse au bac à sable Chromium les espaces de noms utilisateur et l'application plante au lancement (contre-vérification, 30 sept 2026).
- **Étape manuelle** au résumé quand le module vient d'installer Orca : l'ouvrir et y ajouter ses dépôts de travail (`~/projets/…`). Aucune connexion ni secret (exploration, 30 sept 2026).
- **Dock** (spec `module-gnome`) : Orca y prend place **avant VS Code** (décision de l'utilisateur) ; `config/gnome/reglages.dconf` porte le nouveau lanceur `orca-ide.desktop`.

Hors périmètre : réglages d'Orca (agents, comptes des agents — Claude Code est installé par `dev-tools`)  ; mode serveur `orca serve`.

## Capabilities

### New Capabilities
- `module-orca` : Orca depuis son `.deb` officiel le plus récent, profil AppArmor qui le laisse démarrer, étape « ajouter ses dépôts ».

### Modified Capabilities
- `module-gnome` : liste du dock, Orca avant VS Code.

## Impact

- Nouveaux : `modules/53-orca.sh`, `config/orca/apparmor-profile`, `tests/test-orca.sh`.
- Modifiés : `config/gnome/reglages.dconf` (dock), `tests/test-gnome.sh` (liste attendue), `ROADMAP.md` (tableau, vague 6).
- Réseau : API GitHub et téléchargement du `.deb` (~173 Mo), seulement si le paquet manque.
- Système : profil `/etc/apparmor.d/opt.Orca.orca-ide` (chargé par `apparmor_parser`) ; paquet `orca-ide` (`/opt/Orca`, lien `/usr/bin/orca-ide` et assistant de bac à sable `setuid` posés par son script d'installation).
- Postes existants : le dock est mis à jour par `gnome` s'il vaut encore l'ancienne liste du dépôt ; un dock retouché reste intact.
