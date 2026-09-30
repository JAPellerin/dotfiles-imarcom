## Context

Voir `proposal.md`. Modèle : `modules/60-obsidian.sh` (même source, mêmes helpers : `github_release_asset_url`, `apt_install_deb_url`, `pkg_installed`, `manual_step`). Relevés du 30 sept 2026 (exploration, `.deb` téléchargé et ouvert hors du poste) :

| Fait | Mesure |
|---|---|
| Releases `stablyai/orca` | v1.4.217 (29 sept 2026) : `orca-ide_1.4.217_amd64.deb` (173 Mo), `.rpm`, AppImage, macOS, Windows ; publication fréquente |
| Contrôle du `.deb` | `Package: orca-ide`, `Architecture: amd64`, ~582 Mio installés ; `Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0, python3, python3-gi, gir1.2-atspi-2.0, at-spi2-core, xdotool, xclip, xvfb`, `Recommends: libappindicator3-1` — tous résolus sur Ubuntu 26.04 (`libgtk-3-0t64`, `libatspi2.0-0t64`, `libayatana-appindicator3-1` par leurs `Provides`) |
| Script d'installation | `chmod 4755 /opt/Orca/chrome-sandbox` (bac à sable Chromium en `setuid`, « quand les espaces de noms utilisateur ne sont pas disponibles ») ; lien `/usr/bin/orca-ide` → `/opt/Orca/resources/bin/orca-ide` (CLI) ; `postrm` retire ce lien |
| AppArmor | `/opt/Orca/resources/apparmor-profile` livré (profil `orca-ide`, `userns`, non confiné) mais **pas installé** par le paquet |
| Exécutable | `/opt/Orca/orca-ide` : ELF (pas de script d'enveloppe, contrairement à Rocket.Chat) ; le script d'installation n'installe **aucun** profil AppArmor, le `postrm` ne retire que le lien `/usr/bin/orca-ide` (contre-vérification, 30 sept 2026) |
| Lanceur | `/usr/share/applications/orca-ide.desktop` (`Exec=/opt/Orca/orca-ide %U`, `StartupWMClass=orca`) |
| Mises à jour | `resources/app-update.yml` : `provider: github`, `owner: stablyai`, `repo: orca` (mise à jour intégrée d'Electron) |
| Dépôt apt | aucun |

## Goals / Non-Goals

**Goals :** le `.deb` le plus récent, installé par le socle ; rien de retéléchargé sur une relance ; Orca dans le dock avant VS Code.

**Non-Goals :** mises à jour (l'application s'en charge) ; réglages d'Orca ou de ses agents ; `orca serve` ; AppImage.

## Decisions

### D1. Comme `obsidian`
`ORCA_REPO="stablyai/orca"`, `ORCA_ASSET_PATTERN='_amd64\.deb$'`, `ORCA_PACKAGE="orca-ide"`. `module_check` = `pkg_installed orca-ide` et profil AppArmor identique au dépôt (D3). `module_install` : paquet présent → `log_ok` et retour, sans interroger GitHub ; sinon `url=$(github_release_asset_url …) || return 1`, `apt_install_deb_url "$url" orca-ide || return 1`, puis `manual_step`. `module_configure` : profil AppArmor (D3). Description : « Orca (IDE d'agents en parallèle ; .deb officiel des releases GitHub) » — lève l'ambiguïté avec le lecteur d'écran `orca` de GNOME (paquet distinct, aucun conflit : `orca-ide`, `orca-ide.desktop`).

### D2. Étape manuelle
« Ouvrir Orca (menu des applications) et y ajouter ses dépôts de travail (~/projets/…). », déclarée dans `module_install` après une installation réussie (pas de variable vers `module_configure` : sous-shells distincts de `module_call`). Aucune connexion : Orca n'en demande pas (utilisateur, 30 sept 2026) ; les agents qu'il lance ont leur propre connexion (Claude Code : `dev-tools`).

### D3. Profil AppArmor versionné, d'office (contre-vérification, 30 sept 2026)
Le `setuid` de `chrome-sandbox` ne suffit pas : Rocket.Chat, bâti par le même outil (electron-builder, même `chmod 4755` au `postinst`), plantait en VM (`DENIED capable sys_admin profile=unprivileged_userns`, archive `rocketchat`, Context). Sous Ubuntu 24.04+, la création d'un espace de noms non privilégié réussit et seules les capacités sont refusées ensuite : Chromium choisit le bac à sable par espaces de noms plutôt que le `setuid`, et plante. Plutôt que de le constater en VM et de reprendre le design, le module déploie le profil d'office, comme `rocketchat` (D6 de son design) :
- `config/orca/apparmor-profile` : `abi <abi/4.0>`, `include <tunables/global>`, `profile /opt/Orca/orca-ide flags=(unconfined) { userns, include if exists <local/opt.Orca.orca-ide> }` — sur le modèle de celui du paquet, attaché à l'exécutable ELF ;
- copié vers `/etc/apparmor.d/opt.Orca.orca-ide` (nom du chemin du binaire, hors de portée d'un `postrm` qui retirerait `orca-ide`, et distinct d'un profil d'upstream s'il était un jour installé) par `install_system_file`, puis chargé par `run_sudo apparmor_parser -r` **seulement s'il vient d'être écrit** ; chargement en échec → fichier retiré, module en échec nommé ;
- `module_check` : paquet installé **et** profil identique au dépôt (`cmp`) ; `module_configure` porte le profil (plus `return 0`) ; racine surchargeable `ORCA_ROOT` (tests).
Écartés : le profil livré par le paquet (jamais installé) ; `--no-sandbox` ; relâcher `kernel.apparmor_restrict_unprivileged_userns` pour tout le système.

### D4. Dock
`config/gnome/reglages.dconf` : `'orca-ide.desktop'` inséré entre `'com.onepassword.OnePassword.desktop'` et `'com.microsoft.VSCode.desktop'`. Sur un poste déjà réglé par `gnome`, D9 de `gnome` met le dock à jour s'il vaut encore l'ancienne liste ; un dock retouché reste tel quel. C'est la **première mise à jour réelle de la liste** : la validation (tâche 3.2) remet d'abord le dock de la VM, retouché, sur la liste actuelle du dépôt (`dconf reset`, réouverture de session), **avant** de récupérer la nouvelle, pour que D9 soit constaté sans remise à zéro. `tests/test-gnome.sh` : liste attendue mise à jour. Aucun changement du module `gnome`.

### D5. Tests (`tests/test-orca.sh`)
Copie de `tests/test-obsidian.sh` adaptée : doublures `dpkg-query` (fichier), `github_release_asset_url` (URL ou échec sur marqueur, appels comptés), `apt_install_deb_url` (journalise, ajoute `orca-ide`, ou échoue sur marqueur) ; fonctions par `module_call`. `sudo` factice et `apparmor_parser` factice (trace, échec sur marqueur), racine `ORCA_ROOT` du test. Cas : première installation (motif et paquet passés aux helpers, étape manuelle), déjà installé (aucun appel), recherche d'URL en échec (aucun téléchargement ni étape), installation en échec (aucune étape) ; profil : écrit et chargé une fois, relance sans `sudo` ni rechargement, profil modifié → « à faire », réécrit et rechargé, chargement en échec → module en échec et profil retiré ; `module_check` (paquet et profil) ; métadonnées (`NEEDS_GUI`, groupe, description acceptée par `module_meta`).

## Risks / Trade-offs

- [Chemin de l'exécutable changé par l'éditeur (`/opt/Orca` selon `productName`)] → le profil ne s'applique plus et Orca replante, sans erreur du module ; le `postinst` cherche aussi `/opt/orca-ide` et `/opt/orca` : chemin à corriger dans le profil (relevé à chaque mise à jour du design).
- [Mises à jour intégrées d'un `.deb`] → le programme de mise à jour d'Electron remplace le paquet (demande d'authentification possible) ; à observer, sans effet sur le module (`module_check` ne regarde que la présence du paquet).
- [L'éditeur renomme ses `.deb`] → motif sans correspondance, échec nommé ; motif à corriger.
- [Téléchargement de ~173 Mo] → seulement quand le paquet manque.

## Migration Plan

Aucune. Retour arrière : `apt remove orca-ide`, `sudo apparmor_parser -R /etc/apparmor.d/opt.Orca.orca-ide` et retrait du fichier (les réglages d'Orca, dans le dossier de l'utilisateur, ne sont pas touchés) ; retirer `orca-ide.desktop` de `config/gnome/reglages.dconf`.
