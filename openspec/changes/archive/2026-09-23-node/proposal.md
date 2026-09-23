## Why

Les projets de l'utilisateur sont en Node et pnpm (`desjardins-trousse-marketing` : `engines.node >= 20.9.0` ; `desjardins-trousse-marketing-guide` : `packageManager: pnpm@11.20.0`), et `openspec` — l'outil de pilotage de ce dépôt — est un paquet npm global. Sans module `node`, rien de cela n'existe sur un poste neuf, et le futur module `projets` (vague 4) ne peut pas lancer ses installations.

La config shell est déjà prête : `config/shell/commonrc` charge `nvm.sh` (lignes 10 à 12) et `bashrc-extra.sh`/`zshrc` sa complétion. Il ne manque que nvm lui-même, les versions de Node et les outils globaux.

## What Changes

- **Module `node`** (`modules/40-node.sh`, groupe `dev`, dépend de `base` et `shell`, sans session graphique requise) :
  - **nvm** cloné dans `~/.nvm` à une étiquette fixée, selon la méthode « Git Install » de sa documentation — **aucun installateur n'écrit dans les fichiers du shell** (`~/.zshrc` est un lien vers le dépôt) ;
  - **deux versions de Node** : la LTS du moment (`lts/*`) et la 26 ; **la 26 est la version par défaut** ;
  - **pnpm 11** installé sous chacune des deux versions ;
  - **openspec** installé sous la 26 seulement.

Décisions de l'utilisateur (23 sept 2026) :

- **LTS mobile** : « la LTS du moment » et non une version nommée. Fin octobre 2026, la 26 deviendra LTS à son tour ; un poste installé après n'aura alors qu'une version, la 26, qui sera les deux à la fois.
- **Node 26 actif par défaut** : c'est la version des projets.
- **pnpm 11 et non 12** : pnpm ne publie pas de LTS ; la 12 (sortie le 26 août 2026) est la plus récente, la 11 reste maintenue (11.27.1 le 20 septembre, après la 12.5.1) et c'est celle qu'exige le projet `-guide`. pnpm bascule de toute façon sur la version du champ `packageManager` d'un projet.
- **pnpm sous les deux versions, openspec sous la 26 seulement** : un projet passé en LTS a besoin de pnpm ; openspec est un outil de travail qui tourne sur la version active.

Hors périmètre :

- **Corepack** — n'est plus livré avec Node depuis la 25 ; pnpm s'installe par `npm install -g`, comme aujourd'hui dans la WSL.
- **Mise à jour de nvm** au-delà de l'étiquette fixée, et **retrait des anciennes versions** de Node — décisions de l'utilisateur, pas du script.
- **`.nvmrc` et bascule automatique par projet** — aucun projet n'en a aujourd'hui.
- **Claude Code et twg** — contrairement à ce qu'annonçait la ROADMAP, ils ne passent pas par npm (module `dev-tools`).

## Capabilities

### New Capabilities
- `module-node` : le module `node` — nvm, Node LTS et 26 (26 par défaut), pnpm 11 sous chaque version, openspec sous la 26.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/40-node.sh` et `tests/test-node.sh`.
- Fichiers créés hors dépôt : `~/.nvm` (clone git, versions de Node et leurs globaux). Aucune écriture système, aucun `sudo`.
- Réseau : `github.com/nvm-sh/nvm`, `nodejs.org` (binaires de Node), `registry.npmjs.org`. Les tests restent hors ligne.
- **Dans la WSL** : nvm 0.40.3 (même URL d'origine), Node 26.8.2 par défaut, pnpm 11.26.0 et openspec 1.13.0 sous la 26 — **mais aucune LTS** : le module y sera « à faire » et ajoutera la 24 avec son pnpm. C'est le premier cas de validation, sans VM.
- Docs : `ROADMAP.md` (`node` fait ; « Node 26, pnpm 11 » devient « LTS + 26, pnpm 11 »).
