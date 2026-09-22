## Context

Voir `proposal.md`. État du socle au 22 sept 2026 : `link_config` / `config_linked` (`lib/files.sh`) déploient les fichiers versionnés par lien symbolique et constatent leur état ; `apt_install`, `apt_install_pinned`, `apt_remove`, `apt_add_repo`, `apt_update_once`, `pkg_installed` (`lib/apt.sh`) ; `run`, `run_sudo`, `add_cleanup`, `ensure_line`, `SHELL_COMMON_RC` (`lib/core.sh`) ; `ui_spin` (`lib/ui.sh`). `config/shell/commonrc` est un fichier POSIX de 13 lignes (PATH, amorce nvm, `VAULT_ADDR`), lié en `~/.commonrc` et chargé par `zshrc` comme par `bashrc-extra.sh`. `base` installe déjà `curl` et `unzip` ; `fontconfig` n'est installé par personne. Les tests de `lib/` tournent hors ligne et sans sudo, avec des doublures de `run_sudo` et des dossiers système redirigés vers `$TEST_TMP`.

## Goals / Non-Goals

**Goals :** un seul point d'extension pour la config shell des modules, vérifiable par `module_check` sans état mémorisé ; deux helpers dont le comportement est le même pour tous leurs appelants futurs ; tout testable hors ligne.

**Non-Goals :** modifier le contenu actuel de `commonrc` ; toucher aux fichiers propres à un shell (`zshrc`, `bashrc-extra.sh`) ; anticiper les besoins des vagues 3 et 4 (AppImage, `dconf`).

## Decisions

### D1. Chargement des fragments : boucle POSIX en fin de `commonrc`
Ajout à la fin de `config/shell/commonrc` :
```sh
# Fragments déposés par les modules (un lien par module) — voir specs/config-files
for _rc in "$HOME/.commonrc.d"/*.sh; do
  [ -r "$_rc" ] && . "$_rc"
done
unset _rc
```
Pas de garde `[ -d ]` : sans correspondance, le motif reste littéral et `[ -r ]` échoue — comportement POSIX, sans message, y compris dossier absent (c'est le scénario « Aucun fragment » de la spec). `for` plutôt que `find`/`ls` : pas de sous-processus au démarrage de chaque shell interactif, et l'ordre du glob est déjà lexicographique. **En dernier** dans le fichier, pour qu'un fragment puisse surcharger une valeur commune.
Alternative rejetée : `. "$HOME/.commonrc.d"/*.sh` en une ligne — `.` n'accepte qu'un argument en POSIX.

### D2. Un lien par fragment, pas le dossier lié (décision du 22 sept 2026)
`~/.commonrc.d/<module>.sh` → `<dépôt>/config/<module>/commonrc.sh`, par `link_config` (qui crée déjà le dossier parent). Conséquence recherchée : **le fragment n'existe que si son module a été exécuté**, donc `cli-tools` peut poser `alias bat=batcat` sans garde `command -v`, et `config_linked` devient un critère de `module_check` comme les autres liens.
Alternative rejetée : lier le dossier entier (`~/.commonrc.d` → `config/shell/commonrc.d/`). Un seul lien, mais tout fragment présent dans le dépôt serait chargé sur toutes les machines, y compris pour des outils non installés : chaque fragment devrait alors se garder lui-même, et `module_check` n'aurait plus rien à constater.

### D3. Nommage et surcharge pour les tests
Le fragment vit dans le dossier du module qui le possède (`config/cli-tools/commonrc.sh`), pas dans `config/shell/` : un module = un dossier de config, comme `config/git/` et `config/navigateur/`. La cible porte le nom du module (`~/.commonrc.d/cli-tools.sh`). `lib/core.sh` gagne `SHELL_COMMON_RC_DIR="${SHELL_COMMON_RC_DIR:-$HOME/.commonrc.d}"`, à côté de `SHELL_COMMON_RC` et surchargeable de la même façon ; `commonrc` lui-même écrit `$HOME/.commonrc.d` en clair, comme `zshrc` écrit déjà `$HOME/.commonrc` (le fichier est lu par le shell de l'utilisateur, pas par le runner).

### D4. `apt_install_deb_url <url> <paquet>` : apt installe le fichier local
Dans `lib/apt.sh`, à côté des autres helpers apt. `pkg_installed` en garde ; sinon `mktemp -d` + `add_cleanup`, `run curl -fsSL "$url" -o "$tmp/paquet.deb"`, contrôle `dpkg-deb --info` (un 404 renvoyant une page HTML est ainsi rejeté avant apt), puis `apt_update_once` et
`run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$tmp/paquet.deb"` sous `ui_spin`.
`apt-get install <fichier>` (chemin absolu) résout et installe les dépendances en une passe.
Alternative rejetée : `dpkg -i` suivi de `apt-get -f install` — deux étapes, avec un système en état cassé entre les deux si la seconde échoue.
Choix assumé : **pas de vérification de version**. Le helper ne fait rien si le paquet est installé, quelle que soit sa version ; une mise à jour reste une décision du module (le cas se posera pour `obsidian` en vague 3, pas avant).

### D5. `install_font <url> <famille> [dossier]` : extraction en temporaire, copie finale
Nouveau fichier `lib/fonts.sh` (chargé par `setup.sh` comme les autres), plutôt que dans `files.sh` (qui traite des fichiers **versionnés dans le dépôt**) ou dans `apt.sh` (rien d'apt ici, hors l'appoint `fontconfig`).
Déroulé : `apt_install fontconfig` si `fc-list` manque ; garde `fc-list : family | grep -qiF "<famille>"` ; sinon `mktemp -d` + `add_cleanup`, `curl` de l'archive, `unzip -q` dans le temporaire, copie des seuls `*.ttf`/`*.otf` vers `$FONTS_DIR/<dossier>/`, puis `fc-cache -f "$FONTS_DIR"` et re-vérification de la famille. `FONTS_DIR="${FONTS_DIR:-$HOME/.local/share/fonts}"`, surchargeable pour les tests.
L'extraction en temporaire d'abord donne gratuitement l'exigence « pas de dossier de police incomplet » : le dossier final n'est créé qu'une fois l'archive lue avec succès. Installation **utilisateur**, jamais `sudo` : une police par utilisateur suffit et évite `/usr/local/share/fonts`.
`<dossier>` par défaut = `<famille>` sans espaces. Pas de format autre que `.zip` : c'est celui des *releases* Nerd Fonts, et un second format s'ajoutera quand un module en aura besoin.

### D6. Tests hors ligne
`curl` accepte `file://` : les deux helpers se testent avec une URL locale, sans doublure de `curl` ni réseau.
- `tests/test-apt.sh` (cas ajoutés) : `.deb` fabriqué sur place avec `dpkg-deb --build` sur une arborescence minimale ; paquet déjà installé → aucun appel ; fichier non-`.deb` → échec sans appel à `apt-get` ; URL absente → échec nommant l'URL. La doublure `run_sudo` existante compte déjà les `apt-get install`.
- `tests/test-fonts.sh` (nouveau) : `FONTS_DIR` dans `$TEST_TMP`, doublures `fc-list` et `fc-cache` en tête de `PATH` (`fc-list` répond selon un marqueur, comme la doublure `gh` de `tests/test-git.sh`), archive `.zip` fabriquée avec `zip` ou `python3 -m zipfile` ; cas : première installation, famille déjà connue, archive illisible (aucun dossier laissé).
- `tests/test-shell.sh` (cas ajoutés) : un fragment déposé dans `~/.commonrc.d` est vu par `bash -ic` et `zsh -ic` et surcharge `commonrc` ; dossier absent → aucun message.
- `tests/test-files.sh` : rien de nouveau, la convention n'emploie que `link_config`/`config_linked` déjà couverts.

### D7. Le module `shell` n'est pas modifié
La ligne de chargement est dans `config/shell/commonrc`, fichier déjà versionné et déjà lié par `shell` : le module ne gagne ni code ni lien. Sur un poste déjà configuré, `~/.commonrc` étant un lien vers le dépôt, la mise à jour prend effet au `git pull`, sans réexécuter quoi que ce soit.

## Risks / Trade-offs

- [Un fragment cassé (syntaxe, `exit`) casse tous les shells de l'utilisateur, y compris celui qui servirait à le réparer] → fragments courts, POSIX, couverts par `shellcheck` (le motif `config/*/commonrc.sh` sera ajouté à la ligne de lint) ; `[ -r ]` protège du fichier illisible mais pas du contenu fautif. Repli documenté : `bash --norc`.
- [Les fragments sont chargés dans l'ordre lexicographique du nom de module, pas dans l'ordre des dépendances] → aucun fragment ne doit dépendre d'un autre ; si le cas se présente (peu probable : variables et alias), ce sera un préfixe numérique, comme pour les modules.
- [`fc-list`/`fc-cache` absents d'une WSL sans bureau] → `apt_install fontconfig` en tête du helper ; le paquet est léger et sans dépendance graphique.
- [`apt-get install <fichier.deb>` installe une version antérieure à celle du dépôt si le paquet y existe aussi] → cas absent des besoins connus ; le helper est réservé aux logiciels **hors** dépôt apt, ce que la spec énonce.
- [`dpkg-deb --info` valide la forme, pas la provenance] → les `.deb` hors dépôt n'ont pas de signature exploitable ; l'URL HTTPS de l'éditeur est la garantie, comme pour les installateurs `curl` déjà admis par `CLAUDE.md`.

## Migration Plan

Aucune migration : `~/.commonrc.d` est vide tant qu'aucun module n'y dépose de fragment, et le comportement d'un poste existant est inchangé. Retour arrière = retirer la boucle de `commonrc` (les liens de fragments deviennent inertes).

L'ordre d'implémentation est celui des tâches : la boucle `commonrc` et la convention d'abord (elles débloquent `cli-tools`), les deux helpers ensuite (ils débloquent `terminal`).
