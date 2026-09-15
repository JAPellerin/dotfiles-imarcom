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

## Commandes de développement

- `shellcheck setup.sh bootstrap.sh lib/*.sh modules/*.sh` — lint (aucun avertissement toléré)
- `./setup.sh --list` — modules découverts, description, état
- `./setup.sh <module>` — exécuter un module (et ses dépendances) pour le tester isolément
- Test de bout en bout : VM Hyper-V, restaurer le snapshot « vierge », `curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | bash`

## Décisions de conception (confirmées par l'utilisateur, 14 sept 2026)

- **Bash + `gum`** (`apt install gum`, dans les dépôts Ubuntu 26.04). Pas de Node/Python pour la CLI.
- **Dépôt public, aucune donnée sensible.** Hébergé sur GitHub : `https://github.com/JAPellerin/dotfiles-imarcom` (clone HTTPS `https://github.com/JAPellerin/dotfiles-imarcom.git`, raw `https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/`). Lancement sur machine vierge : `curl -fsSL https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh | bash` → installe `git`+`gum` → clone HTTPS dans `~/dotfiles` → `exec setup.sh < /dev/tty`.
- **`setup.sh` tourne en utilisateur**, jamais en root ; `sudo -v` une fois au départ + keepalive en fond. Sans argument : menu `gum` à sélection multiple avec état des modules ; `setup.sh <module...>`, `--all`, `--list`.
- **Contrat de module** : `modules/NN-nom.sh` déclare `MODULE_NAME/DESC/DEPS[/NEEDS_GUI]` et `module_check` / `module_install` / `module_configure`. `module_check` est la seule source de vérité de l'état (pas de fichier d'état). Tout doit être idempotent. Les questions à l'utilisateur se posent au début de `module_install`. Les modules passent par les helpers de `lib/` (jamais `gum` ni `apt` en direct).
- **Secrets via 1Password** : app de bureau + CLI `op` depuis le dépôt apt officiel ; module `1password` exécuté d'office avant les autres ; secrets lus par `op read op://...`, jamais journalisés ; agent SSH de l'app (`SSH_AUTH_SOCK`), activation = étape manuelle affichée en fin d'exécution.
- **Cible** : nouveau laptop de travail Ubuntu 26.04 + GNOME. Tests de bout en bout dans une VM Hyper-V avec snapshot « vierge » ; développement des modules non graphiques dans cette WSL (`has_gui` faux → modules `NEEDS_GUI` sautés).
- Détail des choix et alternatives : `openspec/changes/setup-socle/design.md` (D1–D10).

## Contraintes générales

- **Modulaire** : chaque partie (module) doit pouvoir être lancée séparément, pas seulement dans l'enchaînement complet. Un module = un change OpenSpec.
- **CLI interactive** à la manière de `create-vite` : le script pose des questions, offre des choix (ex. quel navigateur installer) et n'impose pas un profil unique.
- **Installation en ligne de commande, selon la doc officielle** de chaque outil : `apt` (dépôt officiel de l'éditeur avec clé GPG dans `/etc/apt/keyrings/`) ou `curl` de l'installateur officiel. Éviter snap/flatpak/Docker Desktop sauf demande explicite ; ne pas proposer Docker Desktop (l'utilisateur l'a refusé : Docker Engine via le dépôt apt officiel).
- **AppImages** : gestion dédiée — déplacer dans un dossier `Applications`, créer le fichier `.desktop` avec l'icône pour que l'app apparaisse dans le menu d'Ubuntu.
- Les scripts existants (`~/setup-sudo.sh`) séparent ce qui demande `sudo` de ce qui tourne en utilisateur ; `set -euo pipefail`, étapes numérotées `[n/N]`, commentaires en français avec lien vers la doc officielle suivie.
- La config shell commune bash/zsh vit dans `~/.commonrc` (POSIX uniquement), chargé par `.bashrc` et `.zshrc` ; ce qui est propre à un shell reste dans son fichier. Shell cible : zsh + oh-my-zsh + Powerlevel10k.

## Langue

L'utilisateur écrit en français ; réponses, commentaires de code et artefacts OpenSpec en français.
