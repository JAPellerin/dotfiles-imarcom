# Feuille de route

Découpage des modules du script de configuration, convenu le 15 septembre 2026. Un module = un fichier `modules/NN-nom.sh` = un change OpenSpec, réalisé dans l'ordre ci-dessous une fois le socle (`setup-socle`) en place. L'inventaire lisible des outils et des liens officiels reste la note Obsidian « Setup du poste de travail - Linux ».

## Principes du menu

- Sans argument, `setup.sh` affiche un menu `gum` à sélection multiple : les modules **pas encore faits sont cochés d'avance**, les « déjà faits » sont visibles mais décochés. Sur une machine vierge, `Entrée` installe tout ; sur une relance, `Entrée` n'installe que ce qui manque.
- Chaque module déclare un **groupe** (`MODULE_GROUP`) affiché en préfixe dans le menu (`[shell] zsh …`) ; l'ordre d'affichage suit le préfixe `NN` du fichier.
- Un module = un état « fait / pas fait » sans ambiguïté pour `module_check`. Les applications de bureau ont donc **chacune leur module** (choix dans le menu principal) ; seul `navigateur` pose sa question à l'intérieur (quel navigateur) et se contente d'installer ce qui manque à chaque lancement.
- Les profils (`--profile minimal`) ne sont pas prévus dans le socle ; à envisager si le menu devient trop long.

## Modules

| NN | Module | Groupe | Contenu | GUI |
|---|---|---|---|---|
| 00 | `base` | systeme | `apt upgrade`, curl, git, jq, build-essential, … | |
| 10 | `1password` | systeme | app + CLI `op`, agent SSH | app seulement |
| 20 | `shell` | shell | zsh, oh-my-zsh, Powerlevel10k, plugins, `.commonrc` / `.zshrc` / `.bashrc`, **mécanisme de déploiement des fichiers de config** — tranché le 18 sept 2026 : liens symboliques depuis `config/<module>/` via `link_config` (`lib/files.sh`), `chezmoi` réévalué si des différences par machine apparaissent | |
| 21 | `terminal` | shell | Ghostty + config + police Nerd Font | oui |
| 22 | `cli-tools` | shell | ripgrep, fd, fzf, bat, zoxide, lazygit, postgresql-client (`git-delta` est installé par `git`) — **`yq` retiré le 22 sept 2026** : arrivé dans la liste avec la trousse « CLI moderne » standard, sans besoin de l'utilisateur derrière ; à rajouter le jour où un YAML demande à être modifié en script (une ligne, ou `apt_install_deb_url` pour le `yq` v4 de mikefarah, le paquet `yq` d'Ubuntu étant l'enveloppe jq de kislyuk) | |
| 30 | `git` | dev | `user.*`, delta, clé SSH depuis 1Password (convention `op://` fixée ici), `gh`, known_hosts | |
| 40 | `node` | dev | nvm (clone git), Node LTS du moment + 26 (26 par défaut), pnpm 11 sous chacune, openspec sous la 26 | |
| 41 | `docker` | dev | Docker Engine (dépôt apt officiel), groupe `docker` | |
| 42 | `dev-tools` | dev | Claude Code (installateur natif), twg CLI (installateur Atlassian) — sans npm | |
| 25 | `navigateur` | apps | choix Brave / Firefox / Chrome (question interne, dépôts apt officiels en deb822), Firefox en `.deb` de Mozilla à la place du snap (langue : comme Ubuntu / français / anglais), **extension 1Password** pré-installée par stratégie d'entreprise (`/etc/{brave,opt/chrome,firefox}/policies`), **Brave Sync** guidé (code lu dans 1Password, 25ᵉ mot du jour calculé), navigateur par défaut — placé avant `git` (décision du 18 sept 2026) pour que `gh auth login` puisse se connecter à GitHub via l'extension sur un poste neuf ; pas de dépendance `git → navigateur` (elle ferait sauter `git` sans GUI) | oui |
| 51 | `vscode` | apps | VS Code (dépôt Microsoft) + extensions + gnome-keyring | oui |
| 52 | `claude-desktop` | apps | dépôt apt Claude Desktop | oui |
| 60 | `obsidian` | apps | `.deb` officiel (GitHub releases) | oui |
| 61 | `rocketchat` | apps | client de bureau, `.deb` officiel (GitHub releases), serveur `rocketchat.imarcom.net` pré-configuré, profil AppArmor | oui |
| 62 | `thunderbird` | apps | courriel + agendas Google ; archive de Mozilla dans `~/.local/share`, langue d'Ubuntu, dictionnaires en-CA et fr | oui |
| 63 | `spotify` | apps | dépôt apt de Spotify | oui |
| 65 | `vpn` | apps | OpenVPN + NetworkManager ; profil reporté (à retrouver auprès de l'équipe TI) | oui |
| 70 | `gnome` | bureau | réglages dconf, thème, clavier, raccourcis | oui |
| 80 | `projets` | projets | clones Bitbucket Desjardins, `make setup` | |

Le helper AppImage de `lib/` (déplacement dans `~/Applications`, fichier `.desktop` avec icône) et le helper `dconf` sont introduits par la vague qui les emploiera — respectivement la **vague 3** et la **vague 4** (22 sept 2026 : la vague 0 a été réduite aux besoins de la vague 1). Le 23 sept 2026, la vague 3 n'emploie finalement aucune AppImage (Obsidian et Rocket.Chat publient un `.deb`) : le helper AppImage attend le premier module qui en aura besoin. La règle qui demeure : un helper partagé par plusieurs modules d'une même vague s'écrit **avant** elle, dans un change à part, jamais dans l'un des modules — son voisin l'écrirait en double.

## Ordre des changes

Les quatre premiers changes ont été faits un à un. La suite est organisée en **vagues** : les modules d'une vague ne dépendent pas les uns des autres et peuvent être implémentés en parallèle, dans des worktrees git séparés (voir « Vagues et parallélisme »).

1. `setup-socle` — bootstrap, runner, contrat, `lib/`, `base`, `1password` — **fait**, archivé le 18 sept 2026 (avec `1password-integration-app` : connexion guidée sans étape manuelle)
2. `shell` — tranche la gestion des fichiers de config, dont tout le reste dépend — **fait**, archivé le 18 sept 2026
3. `git` — fixe la convention des secrets `op://Private/<Item>/<champ>` — **fait** (18 sept 2026 ; `gh` depuis le dépôt officiel, clé SSH par l'agent avec l'app ou fichier depuis 1Password sans app)
4. `navigateur` (+ extension 1Password, Brave Sync) — **fait** (21 sept 2026 ; validé en VM, archivé le 22 sept 2026), nécessaire avant `gh auth login` sur un poste neuf
5. **Vague 0** — `socle-partage`, un change **sans module** : les fragments de config shell par module (chacun versionne `config/<module>/commonrc.sh` au lieu d'éditer `commonrc`) et les helpers `lib/` que les vagues suivantes partagent — installation d'un `.deb` depuis une URL, AppImage (`~/Applications` + `.desktop` avec icône), police, `dconf`. **À faire seule** : c'est elle qui rend les vagues suivantes parallélisables. — **faite** (22 sept 2026), avec la portée réduite aux besoins de la vague 1 : fragments `~/.commonrc.d/`, `apt_install_deb_url` et `install_font` (`lib/fonts.sh`). Les helpers **AppImage** et **`dconf`** ont été reportés aux vagues 3 et 4, qui les emploieront.
6. **Vague 1** — `cli-tools` — **fait** (22 sept 2026, validé dans la WSL : ripgrep 15.1.0, fd-find 10.3.0, fzf 0.67.0, bat 0.25.0, zoxide 0.9.8, lazygit 0.57.0, postgresql-client 18, tous depuis les dépôts Ubuntu) ; `terminal` — **fait** (22 sept 2026, validé en VM : Ghostty 1.3.0 des dépôts Ubuntu, police MesloLGS NF par `install_font` depuis les quatre fichiers de Powerlevel10k, terminal par défaut par l'alternative Debian **et** `~/.config/xdg-terminals.list` — sur Ubuntu 26.04 GNOME délègue à `xdg-terminal-exec`) ; `docker` — **fait** (23 sept 2026, validé dans la WSL — installation existante reconnue, rien réécrit — et en VM : Docker Engine 29.8.1, containerd.io 2.3.5, buildx 0.37.1, compose 5.5.1 depuis le dépôt apt officiel, suite `resolute` ; groupe `docker`, `hello-world` sans sudo après réouverture de session ; aucun `daemon.json`). **Vague 1 close.**
7. **Vague 2** — `socle-groupes` d'abord, un change **sans module** : helpers d'appartenance à un groupe (`lib/groups.sh`), `docker` réécrit dessus, requis par `claude-desktop` (groupe `kvm`) — **fait** (23 sept 2026) ; puis `node`, `dev-tools`, `vscode` et `claude-desktop`, **sans dépendance entre eux** — corrigé le 23 sept 2026 : Claude Code (installateur natif) et twg (binaire autonome) ne passent pas par npm, contrairement à ce que prévoyait cette feuille de route ; `node` — **fait** (23 sept 2026, validé en WSL et en VM : nvm v0.40.8, Node 24.21.0 LTS + 26.10.0 par défaut, pnpm 11.27.1, openspec 1.13.1) ; `dev-tools` — **fait** (23 sept 2026, validé en WSL et en VM : Claude Code 2.1.280 par l'installateur natif, twg 1.3.1 par l'installateur Atlassian avec `--yes --skip-login --skip-skills`, connexions en étapes manuelles); `vscode` — **fait** (23 sept 2026, validé en VM : VS Code 1.139.0 du dépôt Microsoft, un seul `vscode.sources`, 18 extensions) ; `claude-desktop` — **fait** (23 sept 2026, validé en VM : Claude Desktop 2.7032.0 du dépôt apt d'Anthropic, un seul `claude-desktop.sources` grâce à `/etc/default/claude-desktop`, QEMU pour Cowork, groupe `kvm`). **Vague 2 close.**
8. **Vague 3** — `socle-github` d'abord, un change **sans module** : `github_release_asset_url` (`lib/github.sh`), l'URL du dernier fichier publié dans les releases GitHub d'un éditeur — la dernière release **qui le contient** (celle d'Obsidian n'a qu'un `.apk`) — requis par `obsidian` et `rocketchat` — **fait** (24 sept 2026) ; puis `obsidian`, `rocketchat`, `thunderbird`, `spotify` et `vpn`, sans dépendance entre eux — `vpn` en **installation seule** (OpenVPN et son greffon NetworkManager), la configuration du profil est reportée : profil et méthode de connexion à retrouver auprès de l'équipe TI (23 sept 2026) — **faits** (24 sept 2026, validés en VM) : `obsidian` 1.13.7, `rocketchat` 4.17.2 (profil AppArmor ajouté : sans lui le client plante sous Ubuntu 26.04), `thunderbird` 156.0.1 (langue d'Ubuntu, dictionnaires en-CA et fr par stratégie d'entreprise), `spotify` 1.2.95 ; `vpn` : **installation faite** (OpenVPN 2.7.0, greffon 1.12.5, déjà présents sur Ubuntu 26.04), **configuration du profil reportée** (profil et méthode à retrouver auprès de l'équipe TI)
9. **Vague 4** — `gnome` (après `terminal`, pour le raccourci du terminal par défaut), puis `projets` (après `git`, `node`, `docker`)

## Vagues et parallélisme

Convenu le 22 septembre 2026. Une vague = des modules sans dépendance entre eux, specés ensemble dans une même session (pour que les décisions croisées restent cohérentes), puis implémentés en parallèle.

**Règle : on ne spece qu'une vague d'avance, et on ne la lance qu'une fois la précédente validée en VM.** Raison mesurée sur `navigateur` : après le premier commit de code, `spec.md` n'a été corrigé qu'une seule fois, mais `design.md` cinq fois, dont trois explicitement « vu en VM » (`--allow-downgrades`, sentinelle `First Run`, `Preferences` en `Status: user`). Le *quoi* se spece d'avance ; le *comment* ne survit pas au contact de la machine. Specer plusieurs vagues d'avance revient à corriger autant de designs à chaque découverte.

**Trois ressources partagées** — à connaître avant de toucher quoi que ce soit depuis un worktree :

1. `config/shell/commonrc` — plusieurs modules veulent y ajouter des lignes (fzf, zoxide, bat, nvm, docker). Depuis la vague 0, **ne plus l'éditer** : versionner `config/<module>/commonrc.sh` et le lier par `link_config` vers `~/.commonrc.d/<module>.sh` (un lien par module, chargé seulement si le module est installé).
2. `lib/` — les helpers sont communs à tous les modules. Un helper manquant se rajoute dans la vague 0, ou dans un change à part ; jamais en double dans deux modules d'une même vague.
3. **La VM Hyper-V** — un seul snapshot « vierge », un seul `ssh vm`. Le développement se parallélise, **la validation de bout en bout se fait en file**.

Sans conflit, donc sans précaution particulière : `modules/NN-*.sh` (préfixes déjà attribués par le tableau ci-dessus), `tests/test-*.sh` (`run-all.sh` fait un glob, pas de registre à éditer), `openspec/specs/<capacité>/` et `openspec/changes/`. Seul `ROADMAP.md` produira des conflits, triviaux.
