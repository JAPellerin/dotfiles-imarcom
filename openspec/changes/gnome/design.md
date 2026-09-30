## Context

Voir `proposal.md`. Relevés dans la VM (29 sept 2026, GNOME Shell 50.1, par `ssh vm`) :

| Sujet | Constat |
|---|---|
| `dconf dump /` | lisible par SSH ; ne liste que les clés de la base de l'utilisateur, donc l'écart aux valeurs par défaut — pas besoin d'un relevé « avant » |
| Profil dconf | `/etc/dconf/profile/` ne contient que `ibus` (profil du démon ibus) ; **pas de `user`** : sans lui, seule la base de l'utilisateur est lue |
| Défauts d'Ubuntu | `/usr/share/glib-2.0/schemas/*.gschema.override` (`10_ubuntu-settings`, `10_ubuntu-dock`, …) — en dessous de la base dconf du système dans l'ordre de priorité |
| Réglages de l'utilisateur retenus | `input-sources sources=[('xkb', 'ca')]` ; `interface color-scheme='prefer-dark'`, `gtk-theme='Yaru-dark'`, `icon-theme='Yaru-dark'` ; `background` et `screensaver` : `picture-uri` (et `picture-uri-dark` pour le fond) `file:///usr/share/backgrounds/osselo-Ask_a_friend.jpg`, `picture-options='zoom'`, couleurs `#000000000000` ; `shell/extensions/dash-to-dock` : `dock-position='BOTTOM'`, `dash-max-icon-size=42`, `dock-fixed=false`, `show-trash=false` ; `shell/extensions/ding show-home=false` ; `privacy report-technical-problems=false` ; `system/location enabled=false` ; `settings-daemon/plugins/color night-light-schedule-automatic=false` ; `gtk/gtk4/settings/file-chooser sort-directories-first=true` |
| Écartés (utilisateur) | `peripherals/keyboard numlock-state` (état de la touche Verr Num retenu par GNOME à la fermeture de session, pas une préférence : retiré après le test en VM, 30 sept 2026) ; `settings-daemon/plugins/power sleep-inactive-ac-*` (matériel, laptop) ; tout ce qu'écrit l'extension `tiling-assistant` (`mutter edge-tiling=false`, raccourcis `toggle-tiled-*` vidés, `overridden-settings`, couleur, version) ; état tenu par GNOME ou les applications (`app-picker-layout`, fenêtre des Paramètres, notifications vues, horodatages, migrations, profil de Ptyxis, dossiers d'applications par défaut, `enabled-extensions` = liste d'Ubuntu) |
| Lanceurs connus | VM : `org.gnome.Nautilus.desktop`, `brave-browser.desktop`, `firefox.desktop`, `com.onepassword.OnePassword.desktop` (celui du dock actuel ; `1password.desktop` existe aussi) ; modules : `com.mitchellh.ghostty.desktop`, `google-chrome.desktop`, `thunderbird.desktop` (lanceur posé par le module) ; à relever : VS Code, Claude, Rocket.Chat, Obsidian, Spotify |
| Snapshot vierge, après la première connexion (30 sept 2026) | la base de l'utilisateur porte déjà `input-sources` `ca`, thème sombre (`color-scheme`, `gtk-theme`, `icon-theme`), `numlock-state`, `privacy`, veilleuse, localisation, `sort-directories-first` (mêmes valeurs que celles retenues) et **`favorite-apps=['firefox_firefox.desktop', 'org.gnome.Nautilus.desktop', 'snap-store_snap-store.desktop', 'org.gnome.Yelp.desktop', 'org.gnome.Ptyxis.desktop']`** ; absents : fond, écran verrouillé, `dash-to-dock`, `ding` → D8 |
| Raccourci du terminal | spec `module-terminal` : le raccourci du bureau ouvre Ghostty par `xdg-terminal-exec` — rien à faire ici |

Modèle : `modules/61-rocketchat.sh` (fichiers système par `install_system_file`, commande système à relancer seulement si le fichier a changé, racine `/etc` surchargeable dans les tests).

## Goals / Non-Goals

**Goals :** un poste neuf prend les réglages de l'utilisateur sans rien écraser ; mise à jour du dépôt par simple report d'un `dconf dump` ; `module_check` hors ligne, sans `sudo`, indépendant des retouches de l'utilisateur.

**Non-Goals :** verrouiller des réglages (`locks/`) ; écrire la base de l'utilisateur, hors le dock d'Ubuntu (D8) ; outil de relevé automatique (le report du `dconf dump` reste manuel, fait avec l'utilisateur) ; extensions GNOME.

## Decisions

### D1. Base dconf du système (décision de l'utilisateur, 29 sept 2026 : mécanisme « C »)
Deux fichiers versionnés, copiés par `install_system_file` :
- `config/gnome/dconf-profile` → `/etc/dconf/profile/user` : `user-db:user` puis `system-db:local` (la base de l'utilisateur d'abord : ses valeurs l'emportent).
- `config/gnome/reglages.dconf` → `/etc/dconf/db/local.d/00-dotfiles` : les réglages de base, **au format de `dconf dump`** (sections `[chemin]`, valeurs GVariant), commentaires `#` en tête qui disent comment le mettre à jour.
Puis `run_sudo dconf update` (compile `/etc/dconf/db/local`), **seulement** si l'un des deux fichiers vient d'être écrit ou si la base compilée est absente ou plus ancienne que les réglages (D3).
Alternatives écartées (utilisateur) : `dconf load` dans la base de l'utilisateur (ses retouches seraient écrasées à chaque passage) ; surcharge de schémas `…gschema.override` (format à convertir, clés d'extension selon l'emplacement de leur schéma).
Constante `GNOME_ETC` (racine de `/etc`, surchargeable pour les tests), `GNOME_PROFILE="$GNOME_ETC/dconf/profile/user"`, `GNOME_KEYFILE="$GNOME_ETC/dconf/db/local.d/00-dotfiles"`, `GNOME_DB="$GNOME_ETC/dconf/db/local"`.

### D2. Profil existant
Absent → écrit. Identique (`cmp`) → rien. Différent → `log_error` qui nomme le fichier, retour 1, fichier intact (spec) : un profil posé par un administrateur ou un autre outil ne se fusionne pas à l'aveugle.

### D3. Recompilation
`_gnome_db_fresh` : `/etc/dconf/db/local` existe et n'est pas plus ancien que `00-dotfiles` (`! [[ keyfile -nt db ]]`). Dans `module_configure` : écriture des fichiers (D1, D2) ; si l'un a changé ou si la base n'est pas fraîche → `run_sudo dconf update` ; échec → nommé (une erreur de syntaxe du fichier de réglages s'y montre : sortie au journal).

### D4. Dock
Clé `org/gnome/shell favorite-apps` du fichier de réglages : `['org.gnome.Nautilus.desktop', 'com.mitchellh.ghostty.desktop', 'brave-browser.desktop', 'firefox.desktop', 'google-chrome.desktop', 'com.onepassword.OnePassword.desktop', 'com.microsoft.VSCode.desktop', 'com.anthropic.Claude.desktop', 'thunderbird.desktop', 'rocketchat-desktop.desktop', 'md.obsidian.Obsidian.desktop', 'spotify.desktop', 'org.gnome.TextEditor.desktop']`. GNOME ignore un identifiant sans lanceur installé (spec : l'absent n'empêche pas les autres). Lanceurs relevés sur la VM après l'installation complète (30 sept 2026, tâche 2.2) : VS Code `com.microsoft.VSCode.desktop` (pas `code.desktop`), Claude `com.anthropic.Claude.desktop`, Obsidian `md.obsidian.Obsidian.desktop`, Rocket.Chat `rocketchat-desktop.desktop`, Spotify `spotify.desktop` ; Chrome non installé sur la VM (nom tenu par le module `navigateur`). Éditeur de texte de GNOME (`org.gnome.TextEditor.desktop`, fourni par Ubuntu) ajouté en fin de liste par l'utilisateur dans la VM (30 sept 2026).

### D5. `module_check`
`pkg_installed dconf-cli`, profil identique au dépôt, réglages identiques au dépôt, base compilée fraîche (D3), dock qui n'est plus celui d'Ubuntu (D8 ; l'ancienne liste du dépôt, D9, n'y entre pas : des réglages déployés anciens rendent déjà « à faire »). Seule lecture de `dconf` : ce dock ; les retouches de l'utilisateur ne rendent pas le module « à faire » (spec).

### D6. Métadonnées
`modules/70-gnome.sh` : `MODULE_NAME="gnome"`, `MODULE_DESC="bureau GNOME : clavier ; thème sombre ; fond ; dock ; confidentialité (valeurs par défaut du système)"` (points-virgules : `module_meta` refuse la virgule et « | » dans ce champ — contre-vérification, 30 sept 2026), `MODULE_GROUP="bureau"`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`. `module_install` : `apt_install dconf-cli` (sans effet s'il est présent — c'est le cas sur Ubuntu 26.04, relevé en VM le 30 sept 2026 — mais `dconf update` en dépend : l'installer d'office est plus sûr qu'un relevé).

### D7. Tests (`tests/test-gnome.sh`)
Racine `GNOME_ETC` du test ; `sudo` factice (`fake_sudo`) ; `dconf` factice (`update` touche la base compilée, trace ses appels ; échec sur drapeau). Cas : `dconf-cli` passé à `apt_install` ; `module_check` 1 sans `dconf-cli` ; premier passage → deux fichiers écrits, `dconf update` une fois, `module_check` 0 ; relance → aucun `sudo`, aucun `dconf update` ; réglages du dépôt modifiés → à faire, fichier réécrit, recompilé ; base compilée absente ou plus ancienne → recompilée ; profil différent → échec nommé, intact, aucune recompilation ; `dconf update` en échec → échec nommé ; fichier de réglages : chaque clé retenue présente (dont le dock et son ordre), aucune clé écartée (`power`, `mutter`, `tiling-assistant`) ; métadonnées (`NEEDS_GUI`, groupe) ; D8 (`dconf` factice : `read`/`write` dans un fichier) : dock d'Ubuntu → « à faire », dock du dépôt écrit sans `sudo` ni recompilation, puis « déjà fait » ; dock retouché → « déjà fait », intact ; dock sans valeur → « déjà fait ».

### D8. Dock d'Ubuntu remplacé (décision de l'utilisateur, 30 sept 2026 : option « a »)
Constat du snapshot vierge (Context) : Ubuntu écrit `favorite-apps` dans la base de l'utilisateur à la première connexion ; la valeur par défaut du système (D4) ne s'afficherait donc jamais. Constante `GNOME_DOCK_UBUNTU` : la liste relevée. `_gnome_dock_ubuntu` : `dconf read /org/gnome/shell/favorite-apps` (valeur en vigueur, base de l'utilisateur puis du système) égale à cette liste. `module_configure`, après la recompilation : si vrai → `run dconf write` de la liste de `favorite-apps` lue dans `config/gnome/reglages.dconf` (seule source du dock ; la clé reste aussi valeur par défaut du système, pour un dock remis à zéro). Toute autre valeur, y compris celle du dépôt ou une liste retouchée, n'est jamais réécrite. Valeur absente de la base de l'utilisateur → le défaut du système s'applique déjà, rien à écrire. Sans `sudo` (base de l'utilisateur), dans la session graphique où tourne `setup.sh`.
Alternatives écartées (utilisateur) : toujours écrire le dock (retouches écrasées à chaque passage) ; laisser le dock d'Ubuntu (la décision « le script fixe le dock » ne serait pas tenue).

### D9. Liste du dock mise à jour dans le dépôt (contre-vérification, décision de l'utilisateur, 30 sept 2026)
Constat : GNOME recopie le dock dans la base de l'utilisateur à la connexion (Risks) ; une nouvelle liste du dépôt, simple valeur par défaut, n'y arriverait donc jamais, ce qui casse le cycle `dconf dump` → dépôt → `setup.sh gnome` pour le dock. Dans `module_configure`, **avant** de copier les réglages, `old_dock` : liste `favorite-apps` des réglages déployés (`/etc/dconf/db/local.d/00-dotfiles`, lisible sans `sudo`) ; après la recompilation, dock en vigueur (`dconf read`) : égal à la liste d'Ubuntu → liste du dépôt écrite (D8) ; sinon égal à `old_dock`, non vide et différent de la nouvelle liste → nouvelle liste écrite (« Dock mis à jour ») ; sinon rien. Un dock retouché ne vaut ni l'une ni l'autre : jamais réécrit. `module_check` inchangé : des réglages déployés différents du dépôt le rendent déjà « à faire », et la bascule se fait dans le même passage. Tests (D7) : ancienne liste → nouvelle écrite ; dock retouché → intact après mise à jour du dépôt ; relance sur le dock du dépôt → aucune écriture.

## Risks / Trade-offs

- [Base de l'utilisateur déjà remplie : les défauts ne se voient pas] → c'est voulu (spec) ; dans la VM, qui porte déjà ces valeurs, la validation remet à zéro les clés concernées pour observer la base du système (tâche 2.1).
- [Clés écrites par l'assistant de première connexion d'un poste vraiment neuf (disposition du clavier, localisation, rapports d'erreur)] → pour ces clés, la valeur du système ne s'applique jamais, sans message (la base de l'utilisateur passe devant — voulu, spec) ; la tâche 2.2 relève `dconf dump /` sur le snapshot vierge **après la première connexion et avant le module**, puis vérifie chaque clé retenue après le module, et consigne celles que l'assistant écrit (contre-vérification, 30 sept 2026).
- [Dock d'Ubuntu différent sur le laptop (autre version de l'installateur, mise à jour d'Ubuntu)] → la liste n'est plus reconnue et le dock n'est pas remplacé, sans erreur ; relever `dconf read /org/gnome/shell/favorite-apps` sur le laptop après la première connexion et corriger `GNOME_DOCK_UBUNTU` si besoin (tâche 2.2).
- [Dock réécrit par GNOME à la connexion] → constaté en VM (30 sept 2026) : après `dconf reset` de `favorite-apps` et réouverture de session, la base de l'utilisateur porte de nouveau la clé, à la valeur du système (liste du dépôt). Sans D9, une liste du dock mise à jour dans le dépôt n'atteindrait jamais un poste déjà installé ; D9 la fait suivre tant que l'utilisateur n'a pas retouché son dock.
- [Échec du `dconf write` de D9 (pas de bus de session, par ex.)] → le module échoue en le nommant, mais les nouveaux réglages sont déjà déployés : au passage suivant, l'ancienne liste égale la nouvelle et le dock n'est plus mis à jour, sans message. Cas improbable (le module tourne dans la session graphique) ; remède : `dconf reset /org/gnome/shell/favorite-apps`, puis rouvrir la session. Accepté plutôt que de décider du dock avant la copie des réglages, ce qui écrirait dans la base de l'utilisateur avant la recompilation (contre-vérification, 30 sept 2026).
- [Dock retouché par l'utilisateur, puis liste du dépôt mise à jour] → le dock n'est pas remplacé (voulu, spec) ; pour prendre la nouvelle liste : `dconf reset /org/gnome/shell/favorite-apps`, puis rouvrir la session.
- [Prise en compte en cours de session] → relevé en VM (30 sept 2026) : `dconf update` notifie aussitôt la session ouverte ; GNOME Shell recharge ses réglages dans la seconde (erreurs JS sans suite dans son journal), et le clavier a cessé de répondre un court moment avant de revenir seul, vraisemblablement par ce rechargement (disposition de clavier réappliquée). Sans conséquence durable ; la spec promet l'effet « à la session suivante », et une recompilation n'a lieu que si les réglages du dépôt ont changé (D3).
- [Erreur de syntaxe dans le fichier de réglages après une mise à jour] → `dconf update` échoue, nommé ; test du fichier (D7) sur les clés attendues.
- [Profil dconf posé par un tiers plus tard] → le module échoue en le nommant (D2) plutôt que de l'écraser.
- [Nom de lanceur changé par un éditeur] → l'icône disparaît du dock sans erreur (identifiant ignoré) ; relever et corriger au cycle de mise à jour.

## Migration Plan

Poste existant (VM) : la base de l'utilisateur garde ses valeurs ; seul ce qui n'y est pas réglé prend les défauts. Retour arrière : retirer `/etc/dconf/profile/user` et `/etc/dconf/db/local.d/00-dotfiles`, puis `dconf update`.
