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
| 22 | `cli-tools` | shell | ripgrep, fd, fzf, bat, zoxide, lazygit, postgresql-client, yq (`git-delta` est installé par `git`) | |
| 30 | `git` | dev | `user.*`, delta, clé SSH depuis 1Password (convention `op://` fixée ici), `gh`, known_hosts | |
| 40 | `node` | dev | nvm, Node 26, pnpm 11, globaux npm (openspec) | |
| 41 | `docker` | dev | Docker Engine (dépôt apt officiel), groupe `docker` | |
| 42 | `dev-tools` | dev | Claude Code, twg CLI | |
| 25 | `navigateur` | apps | choix Brave / Firefox / Chrome (question interne) + **extension 1Password** — placé avant `git` (décision du 18 sept 2026) pour que `gh auth login` puisse se connecter à GitHub via l'extension sur un poste neuf ; pas de dépendance `git → navigateur` (elle ferait sauter `git` sans GUI) | oui |
| 51 | `vscode` | apps | VS Code (dépôt Microsoft) + extensions + gnome-keyring | oui |
| 52 | `claude-desktop` | apps | dépôt apt Claude Desktop | oui |
| 60 | `obsidian` | apps | `.deb` officiel (GitHub releases) | oui |
| 61 | `rocketchat` | apps | client de bureau | oui |
| 62 | `thunderbird` | apps | courriel + agendas Google | oui |
| 63 | `spotify` | apps | facultatif | oui |
| 65 | `vpn` | apps | OpenVPN + NetworkManager, profil `.ovpn` lu dans 1Password | oui |
| 70 | `gnome` | bureau | réglages dconf, thème, clavier, raccourcis | oui |
| 80 | `projets` | projets | clones Bitbucket Desjardins, `make setup` | |

Le helper AppImage de `lib/` (déplacement dans `~/Applications`, fichier `.desktop` avec icône) est introduit par le premier module qui en a besoin.

## Ordre des changes

1. `setup-socle` — bootstrap, runner, contrat, `lib/`, `base`, `1password` — **fait**, archivé le 18 sept 2026 (avec `1password-integration-app` : connexion guidée sans étape manuelle)
2. `shell` — tranche la gestion des fichiers de config, dont tout le reste dépend — **fait**, archivé le 18 sept 2026
3. `git` — fixe la convention des secrets `op://Private/<Item>/<champ>` — **fait** (18 sept 2026 ; `gh` depuis le dépôt officiel, clé SSH par l'agent avec l'app ou fichier depuis 1Password sans app)
4. `navigateur` (+ extension 1Password) — **prochain** : nécessaire avant `gh auth login` sur un poste neuf
5. `cli-tools`, `terminal`
6. `node`, `docker`, `dev-tools`
7. `vscode`, `claude-desktop`
8. `obsidian`, `rocketchat`, `thunderbird`, `spotify`, `vpn`
9. `gnome`
10. `projets`
