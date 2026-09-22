## Why

Les vagues suivantes du `ROADMAP.md` implémentent plusieurs modules en parallèle, dans des worktrees git séparés. Deux points du socle les feraient entrer en collision : **`config/shell/commonrc`**, que `cli-tools`, `node` et `docker` veulent tous enrichir (un seul fichier, autant de conflits), et **les helpers manquants de `lib/`**, qu'un module écrirait faute de les trouver — pour les voir réécrits différemment par son voisin de vague.

Cette vague 0 pose donc les deux mécanismes partagés **avant** d'ouvrir les worktrees, et ne fait que ça : aucun module n'est ajouté. Sa portée est volontairement limitée à ce dont la **vague 1** (`cli-tools`, `terminal`, `docker`) a besoin ; les helpers AppImage et `dconf` attendront la vague qui les emploiera, conformément à la règle « une seule vague specée d'avance » inscrite dans `ROADMAP.md` le 22 sept 2026.

## What Changes

- **Fragments de configuration shell (`~/.commonrc.d/`)** — nouveau point d'extension pour les modules :
  - `config/shell/commonrc` charge, à la fin, tous les `~/.commonrc.d/*.sh` dans l'ordre lexicographique, en syntaxe POSIX, sans erreur si le dossier est absent ou vide ;
  - **convention** : un module qui a besoin d'ajouter des variables ou des alias communs à bash et zsh versionne `config/<module>/commonrc.sh` et le déploie par `link_config` vers `~/.commonrc.d/<module>.sh` — un lien par fragment, de sorte que `config_linked` serve de source de vérité à `module_check` et que **seuls les modules installés chargent leur fragment** (décision du 22 sept 2026) ;
  - à partir de là, `config/shell/commonrc` **ne doit plus être édité par un module**.
- **`apt_install_deb_url <url> <paquet>`** (`lib/apt.sh`) : installe un paquet `.deb` téléchargé depuis une URL (éditeur ou *release* GitHub) en laissant apt résoudre les dépendances, sans rien faire si le paquet est déjà installé. Premier besoin connu : `terminal` (Ghostty, selon ce que la recon de la vague 1 établira), puis `obsidian` en vague 3.
- **`install_font <url> <famille> [dossier]`** (nouveau `lib/fonts.sh`) : installe une police depuis une archive `.zip` dans `~/.local/share/fonts/`, rafraîchit le cache `fontconfig` et ne fait rien si la famille est déjà connue du système. Besoin de `terminal` (Nerd Font pour Powerlevel10k et Ghostty).
- **Tests** : `tests/test-fonts.sh`, cas ajoutés à `tests/test-apt.sh` (`.deb` par URL) et `tests/test-files.sh` / `tests/test-shell.sh` (fragments), tous hors ligne et sans sudo comme les existants.

Hors périmètre, assumé explicitement :

- **Helpers AppImage et `dconf`** — reportés à la vague qui les emploiera (vague 3 et vague 4). On ne sait pas encore si Rocket.Chat et Spotify se livrent en `.deb` ou en AppImage ; écrire le helper maintenant serait le specer trois vagues d'avance.
- **Migration du contenu actuel de `commonrc`** — `PATH`, `nvm` et `VAULT_ADDR` y restent tels quels. Déplacer l'amorce `nvm` dans un fragment appartenant au module `node` retirerait `nvm` du `~/.commonrc` de cette WSL avant que `node` n'existe ; cette reprise appartient au module `node` (vague 2).
- **Intégrations propres à un shell** — `config/shell/zshrc` active déjà `fzf` et `zoxide` sous garde `command -v` ; `config/shell/bashrc-extra.sh` ne le fait pas. Cette asymétrie est antérieure et reste telle quelle : `cli-tools` seul la rencontrera en vague 1, sans concurrence d'un autre module sur ces fichiers.
- **Aucun module nouveau, aucun module existant modifié** : `shell` ne gagne que la ligne de chargement dans son fichier versionné.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `config-files` : nouvelle exigence — convention de dépôt des fragments `commonrc.d` par les modules (un lien par fragment, constaté par le helper de vérification).
- `module-shell` : l'exigence « Fichiers de configuration liés depuis le dépôt » évolue — `~/.commonrc` charge désormais `~/.commonrc.d/*.sh`.
- `module-contract` : l'exigence « Accès aux helpers du socle » évolue (deux helpers de plus dans la liste offerte aux modules) ; deux exigences nouvelles décrivent le comportement du helper `.deb` par URL et du helper de police.

## Impact

- `lib/apt.sh` étendu (`apt_install_deb_url`), nouveau `lib/fonts.sh` (`install_font`), chargé par `setup.sh` comme les autres fichiers de `lib/`.
- `config/shell/commonrc` : boucle de chargement ajoutée à la fin (POSIX, sans `bash`isme).
- Nouvelle constante surchargeable `SHELL_COMMON_RC_DIR` dans `lib/core.sh`, à côté de `SHELL_COMMON_RC`, pour que les tests pointent ailleurs que `~`.
- Réseau : les deux nouveaux helpers téléchargent (`curl`) ; leurs tests restent hors ligne (URL `file://` ou archive fabriquée sur place).
- Paquets : `fontconfig` (pour `fc-list`/`fc-cache`) installé par le helper de police s'il manque ; `unzip` est déjà fourni par `base`.
- Docs : `ROADMAP.md` (vague 0 faite), `CLAUDE.md` (mention de `commonrc.d/` dans la section sur la config shell commune).
- Aucun changement visible pour l'utilisateur d'un poste déjà configuré : `~/.commonrc.d` est simplement vide tant qu'aucun module n'y dépose de fragment.
