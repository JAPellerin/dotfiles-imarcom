## Context

Voir `proposal.md`. Le socle fournit `ensure_git_clone <url> <dossier> [options git clone]` (clone si absent, rien si même origine, échec nommé si dossier étranger, pas de mise à jour), `run`, `ui_spin`, `log_*`. `config/shell/commonrc` charge `$NVM_DIR/nvm.sh` ; `bashrc-extra.sh` et `zshrc` chargent sa complétion.

Mesures du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Dernière nvm | v0.40.8 ; README, « Git Install » : `git clone https://github.com/nvm-sh/nvm.git ~/.nvm` puis `git checkout v0.40.8` |
| Installateur de nvm | ajoute ses lignes à `~/.bashrc`/`~/.zshrc` (sauf `PROFILE=/dev/null`) |
| Node | LTS courante : 24 (« Krypton », v24.21.0) ; 26 : v26.10.0, « Current », LTS fin octobre 2026 |
| pnpm | `latest` = 12.5.1, `latest-11` = 11.27.1 (20 sept 2026) ; aucune étiquette LTS |
| WSL | `~/.nvm` clone de `https://github.com/nvm-sh/nvm.git` (v0.40.3) ; alias `default` → `26` ; `alias/lts/*` → `lts/krypton` ; `nvm version lts/*` → `N/A` ; globaux sous `versions/node/v26.8.2/lib/node_modules/` : `pnpm` (11.26.0), `@fission-ai/openspec`, `npm` |
| Coût | `nvm version lts/*` : 0,2 s, hors ligne (lit les alias locaux) |

## Goals / Non-Goals

**Goals :** deux versions de Node, la 26 par défaut, pnpm 11 sous chacune, openspec sous la 26 ; aucun fichier du shell touché ; `module_check` hors ligne.

**Non-Goals :** mettre nvm à jour ; retirer des versions ; `.nvmrc`.

## Decisions

### D1. nvm par `ensure_git_clone`, étiquette fixée
`ensure_git_clone https://github.com/nvm-sh/nvm.git "$NVM_DIR" --branch v0.40.8 --depth 1` — `--branch` accepte une étiquette. C'est la méthode « Git Install » de la doc de nvm, faite par le helper du socle, et **aucun script n'écrit dans `~/.zshrc`**, qui est un lien vers `config/shell/zshrc`. L'étiquette est une constante du module (`NODE_NVM_TAG`). Sur la WSL, le clone existant (même origine, v0.40.3) est conservé : `ensure_git_clone` ne met jamais à jour.
Alternative rejetée : `curl …/install.sh | PROFILE=/dev/null bash` — marche, mais repose sur une variable pour ne pas toucher au dépôt, et refait ce que le helper fait déjà.

### D2. nvm lancé dans un bash enfant, par `run`
nvm est une fonction shell qui modifie le `PATH` de l'appelant. Le module l'appelle dans un bash enfant : `run bash -c '. "$NVM_DIR/nvm.sh" && nvm "$@"' nvm <args…>` (fonction `_node_nvm`). Le journal reçoit la sortie, le runner garde son environnement, et l'interaction de `nvm.sh` avec `set -u` du runner ne se pose pas. Les installations longues passent sous `ui_spin`.

### D3. Versions : `lts/*` et `26`, par défaut `26`
`module_install` : `nvm install --lts`, `nvm install 26`, puis `nvm alias default 26`. `nvm install` rafraîchit les alias `lts/*` locaux : c'est ce qui fait « bouger » la LTS au passage suivant du module. `nvm install 26` sur un poste qui a déjà une 26 installe la dernière 26 si elle manque — voulu, c'est une installation, pas un constat.
Les versions effectives sont relues après installation par `nvm version lts/*` et `nvm version 26` ; si elles sont égales (LTS devenue la 26), la suite ne traite qu'une version.

### D4. Globaux par version, installés par `nvm exec`
Pour chaque version effective (LTS, 26, dédoublonnées) : pnpm 11 si `lib/node_modules/pnpm/package.json` n'annonce pas une 11 → `nvm exec <v> npm install -g pnpm@11`. Pour la 26 seulement : `@fission-ai/openspec` s'il manque → `nvm exec <v> npm install -g @fission-ai/openspec`. Lire le `package.json` sur disque plutôt que lancer `pnpm --version` : hors ligne, instantané, sans dépendre du `PATH`.
openspec n'est pas épinglé : c'est l'outil de ce dépôt, sa dernière version est la bonne.

### D5. `module_check` hors ligne
Vrai si : `$NVM_DIR/nvm.sh` existe ; `nvm version lts/*` et `nvm version 26` ne répondent pas `N/A` ; `nvm version default` commence par `v26.` ; pnpm 11 sous les deux versions (D4) ; openspec sous la 26. `nvm version` lit les alias locaux : la « LTS courante » est celle que nvm a vue à sa dernière installation. Conséquence assumée : après le passage de la 26 en LTS, un poste reste « déjà fait » tant que nvm n'a pas rafraîchi ses alias — sans dommage, puisque la 26 y est déjà.
Ni l'étiquette de nvm ni la version exacte de Node ne sont exigées : un poste plus ancien mais complet est « déjà fait ».

### D6. Dépendance à `shell`
`MODULE_DEPS="base shell"` : sans `shell`, `~/.commonrc` ne charge pas nvm et aucun nouveau shell ne trouverait `node` — le module ne produirait pas son effet s'il était lancé seul (même raison que `cli-tools` D7). `git` et `curl` viennent de `base`.

### D7. Tests
`tests/test-node.sh` (nouveau) : `NVM_DIR` dans `$TEST_TMP`, un faux `nvm.sh` qui définit une fonction `nvm` pilotée par des fichiers (versions installées, alias `lts/*`, `default`) et qui simule `install`, `alias` et `exec … npm install -g` en créant les dossiers et `package.json` attendus ; `ensure_git_clone` remplacé par une doublure qui crée le faux clone et compte ses appels. Cas : première application (deux versions, défaut 26, pnpm sous les deux, openspec sous la 26) ; LTS = 26 → une seule version, un seul pnpm ; réexécution → aucun appel ; pnpm 12 → remplacé ; openspec manquant → installé sous la 26 seulement ; `module_check` sur chacune de ses conditions ; aucun fichier du shell écrit dans le `HOME` isolé.

## Risks / Trade-offs

- [La LTS « du moment » change sous nos pieds] → c'est le choix de l'utilisateur ; `module_check` hors ligne ne le voit qu'au rafraîchissement suivant des alias (D5).
- [`nvm install 26` télécharge une nouvelle 26 lors d'une relance] → seulement quand le module est « à faire » ; les globaux sont alors installés sous la nouvelle version (D4), l'ancienne reste.
- [nvm figé à v0.40.8] → constante à relever à la main ; le clone existant n'est jamais mis à jour.
- [Supply chain npm] → pnpm épinglé en majeure 11 ; openspec à sa dernière version, choix assumé pour l'outil de ce dépôt.

## Migration Plan

Aucune : la WSL garde son clone et sa 26, et reçoit la LTS. Retour arrière : `rm -rf ~/.nvm` (la config shell tolère son absence).
