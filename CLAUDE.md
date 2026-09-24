# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

Script de configuration complète d'un poste de travail/développement sous **Ubuntu 26.04 LTS (resolute)**, du zéro jusqu'à un environnement prêt à l'emploi. Objectif : la grande majorité des logiciels, outils et leurs configurations sont gérés par le script ; le moins d'étapes manuelles possible après coup.

Ce dépôt part de zéro. Un premier script du genre a été fait la semaine du 8 septembre 2026 avec peu de supervision (voir `~/setup-sudo.sh` et `~/vault-sudo.sh`, hors dépôt) ; ici l'utilisateur guide le travail étape par étape pour garantir le contexte. **Ne pas anticiper ni élargir le périmètre : attendre les directives de l'utilisateur pour chaque partie.**

## Développement piloté par les specs (OpenSpec)

Tout changement passe par OpenSpec (`openspec/`, schéma `spec-driven`). Les artefacts sont rédigés en **français**, en gardant les en-têtes structurels et les mots-clés SHALL/MUST en anglais (voir `openspec/config.yaml`).

Workflow via les commandes `/opsx:*` (définies dans `.claude/commands/opsx/`) :

- `/opsx:explore` — explorer/clarifier avant de proposer
- `/opsx:propose <nom-ou-description>` — crée le change et ses artefacts (proposal, specs delta, design, tasks). **Planification seulement** : ne pas implémenter dans la même réponse.
- `/opsx:apply` — implémente les tâches d'un change existant
- `/opsx:sync` — pousse les deltas de specs vers `openspec/specs/`
- `/opsx:archive` — archive un change terminé

Commandes utiles : `openspec list`, `openspec status --change <nom>`, `openspec validate <nom> --strict`, `openspec show <nom>`.

**Renvois depuis le code** (23 sept 2026, change `menage`) : un commentaire renvoie à la spec principale, `openspec/specs/<capacité>/spec.md`, stable ; au design par son chemin d'archive, `openspec/changes/archive/<date>-<nom>/design.md`. Pendant un change actif, un renvoi à `openspec/changes/<nom>/…` est permis, mais **l'archivage le corrige dans la même opération** : `tests/test-refs.sh` vérifie que chaque chemin `openspec/…` cité dans `lib/`, `modules/`, `config/`, `setup.sh` et `bootstrap.sh` existe, et échoue sur un renvoi laissé mort.

## Commandes de développement

- `shellcheck setup.sh bootstrap.sh lib/*.sh modules/*.sh tests/*.sh tests/fixtures/*/*.sh config/shell/commonrc config/shell/bashrc-extra.sh $(git ls-files 'config/*/commonrc.sh')` — lint (aucun avertissement toléré). Le `git ls-files` couvre les fragments `commonrc.d` des modules ; il ne donne rien tant qu'aucun module n'en dépose, là où un motif `config/*/commonrc.sh` ferait échouer `shellcheck` sur un fichier inexistant.
- `bash tests/run-all.sh` (ou `bash tests/test-<sujet>.sh`) — tests Bash maison de `lib/` et du runner, hors ligne et sans sudo (modules factices sous `tests/fixtures/` — jeux `modules/`, `contrat/`, `cycle/`, `dep-inconnue/` — et `MODULES_DIR=tests/fixtures/modules ./setup.sh` pour essayer le runner dessus) ; `bash tests/demo-ui.sh` — démo interactive des wrappers `gum`
- `./setup.sh --list` — modules découverts, description, état
- `./setup.sh <module>` — exécuter un module (et ses dépendances) pour le tester isolément
- Test de bout en bout : VM Hyper-V, restaurer le snapshot « vierge », `curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | bash`

## Décisions de conception (confirmées par l'utilisateur, 14 sept 2026)

- **Bash + `gum`** (`apt install gum`, dans les dépôts Ubuntu 26.04). Pas de Node/Python pour la CLI.
- **Dépôt public, aucune donnée sensible.** Hébergé sur GitHub : `https://github.com/JAPellerin/dotfiles-imarcom` (clone HTTPS `https://github.com/JAPellerin/dotfiles-imarcom.git`, raw `https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/`). Lancement sur machine vierge : `curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | bash` → installe `git`+`gum` → clone HTTPS dans `~/dotfiles` → `exec setup.sh < /dev/tty`.
- **`setup.sh` tourne en utilisateur**, jamais en root ; `sudo -v` une fois au départ + keepalive en fond. Sans argument : menu `gum` à sélection multiple avec état des modules ; `setup.sh <module...>`, `--all`, `--list`.
- **Contrat de module** : `modules/NN-nom.sh` déclare `MODULE_NAME/DESC/DEPS[/NEEDS_GUI]` et `module_check` / `module_install` / `module_configure`. `module_check` est la seule source de vérité de l'état (pas de fichier d'état). Tout doit être idempotent. Les questions à l'utilisateur se posent au début de `module_install`. Les modules passent par les helpers de `lib/` (jamais `gum` ni `apt` en direct). Fichiers de config : versionnés dans `config/<module>/` (sans point initial) et amenés dans `~` par `link_config` (lien symbolique, sauvegarde `.bak`) ; état constaté par `config_linked` ; dépôts git tiers via `ensure_git_clone` ; fichiers système (`/etc/…`) copiés par `install_system_file` (idempotent, jamais des liens) ; `apt_install_pinned` (version choisie par l'épinglage apt), `apt_remove` et `apt_install_deb_url` (paquet `.deb` téléchargé depuis une URL, pour un logiciel distribué hors dépôt apt) en plus d'`apt_install`/`apt_add_repo` ; URL de ce `.deb` dans les releases GitHub de l'éditeur par `github_release_asset_url <propriétaire/dépôt> <motif>` (`lib/github.sh` — dernière release publiée qui contient un fichier au nom correspondant au motif, expression régulière ancrée par le module ; jamais dans `module_check`) ; polices installées pour l'utilisateur par `install_font <famille> <dossier> <url...>` (`lib/fonts.sh` — chaque URL est une archive `.zip` ou un fichier `.ttf`/`.otf`, selon son extension), état constaté par `font_installed` (comparaison exacte de la famille) ; appartenance de l'utilisateur à un groupe système par `ensure_user_in_group <groupe>` (`lib/groups.sh` — crée le groupe s'il manque, puis `usermod -aG`), constatée par `user_in_group` dans la base des groupes (jamais `id -nG`), et `group_relogin_step <groupe>` pour déclarer « rouvrir la session » tant que la session ne porte pas le groupe.
- **Extensions de navigateur** (21 sept 2026) : pré-installées par **stratégie d'entreprise** (`ExtensionSettings`, mode `normal_installed`) — fichiers versionnés dans `config/navigateur/`, copiés vers `/etc/brave/policies/managed/`, `/etc/opt/chrome/policies/managed/` et `/etc/firefox/policies/policies.json` ; jamais via le magasin ni le profil du navigateur (préférences protégées par HMAC). Étapes que seule l'interface permet (Brave Sync) : parcours guidé sur le modèle du module `1password` (ouvrir la page, consigne, attendre un signal sur disque, « Passer » possible).
- **Secrets via 1Password** : app de bureau + CLI `op` depuis le dépôt apt officiel ; module `1password` exécuté d'office avant les autres ; secrets lus par `op read op://...`, jamais journalisés. **Convention (18 sept 2026, assouplie le 21 sept 2026)** : `op://<coffre>/<Item>/<champ>` — coffre `Private` par défaut, un autre coffre est nommé explicitement dans la constante du module (ex. `op://Imarcom/Brave Sync Code/notesPlain`) ; un item par service nommé comme dans 1Password (ex. `GitHub SSH Key`), champs tels qu'affichés (`private key`, `public key`, `token` ; `notesPlain` pour le contenu d'une note sécurisée) ; clé privée SSH avec `?ssh-format=openssh` (sinon PKCS#8) ; les modules déclarent leurs références en constantes en tête de fichier et lisent par `op_read` dans une variable (jamais `op` direct, jamais dans une commande journalisée) ; quand l'app est installée, l'agent sert les clés SSH et rien n'est écrit sur disque ; agent SSH de l'app (`SSH_AUTH_SOCK`), activation guidée et vérifiée par le module (l'app est ouverte sur ses réglages, le script attend le socket de l'agent : ces réglages sont signés par l'app, aucune API — vérifié le 18 sept 2026).
- **Cible** : nouveau laptop de travail Ubuntu 26.04 + GNOME. Tests de bout en bout dans une VM Hyper-V avec snapshot « vierge » ; développement des modules non graphiques dans cette WSL (`has_gui` faux → modules `NEEDS_GUI` sautés).
- Détail des choix et alternatives : `openspec/changes/archive/2026-09-18-setup-socle/design.md` (D1–D11). Tranché le 17 sept 2026 : `has_gui` faux sous WSL (`$WSL_DISTRO_NAME`), journal via les helpers `run`/`run_sudo`/`apt_*` sans redirection globale (pour préserver `gum` et `sudo`), tests versionnés sous `tests/`.
- **Découpage des modules et ordre des changes** : `ROADMAP.md` (15 sept 2026). Menu : modules non faits précochés, préfixe de groupe `[shell]`, une app de bureau = un module.

## Contraintes générales

- **Modulaire** : chaque partie (module) doit pouvoir être lancée séparément, pas seulement dans l'enchaînement complet. Un module = un change OpenSpec.
- **CLI interactive** à la manière de `create-vite` : le script pose des questions, offre des choix (ex. quel navigateur installer) et n'impose pas un profil unique.
- **Installation en ligne de commande, selon la doc officielle** de chaque outil : `apt` (dépôt officiel de l'éditeur avec clé GPG dans `/etc/apt/keyrings/`) ou `curl` de l'installateur officiel. Éviter snap/flatpak/Docker Desktop sauf demande explicite ; ne pas proposer Docker Desktop (l'utilisateur l'a refusé : Docker Engine via le dépôt apt officiel).
- **AppImages** : gestion dédiée — déplacer dans un dossier `Applications`, créer le fichier `.desktop` avec l'icône pour que l'app apparaisse dans le menu d'Ubuntu.
- Les scripts existants (`~/setup-sudo.sh`) séparent ce qui demande `sudo` de ce qui tourne en utilisateur ; `set -euo pipefail`, étapes numérotées `[n/N]`, commentaires en français avec lien vers la doc officielle suivie.
- La config shell commune bash/zsh vit dans `~/.commonrc` (POSIX uniquement), chargé par `.bashrc` et `.zshrc` ; ce qui est propre à un shell reste dans son fichier. **Un module n'édite jamais `config/shell/commonrc`** : il versionne `config/<module>/commonrc.sh` et le lie par `link_config` vers `~/.commonrc.d/<module>.sh`, que `commonrc` charge en dernier (un lien par module, donc chargé seulement si le module est installé, et `config_linked` sert de critère à `module_check`). Shell cible : zsh + oh-my-zsh + Powerlevel10k. Sources : `config/shell/` (`zshrc`, `commonrc`, `p10k.zsh` liés dans `~` ; `bashrc-extra.sh` chargé par une ligne ajoutée au `.bashrc` d'Ubuntu).

## Langue

L'utilisateur écrit en français ; réponses, commentaires de code et artefacts OpenSpec en français.
