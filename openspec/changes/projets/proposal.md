## Why

Sur un poste neuf, les dépôts de travail sont à recloner un par un, aux bons endroits, et le poste doit connaître ce que le projet client ne peut pas poser lui-même sans `sudo` : l'autorité de certification locale (`mkcert`) de son proxy https et ses domaines locaux dans `/etc/hosts`. S'y ajoute l'accès SSH à l'ancien serveur du client, dont la clé est aujourd'hui un fichier sur le seul poste actuel. Dernier module de la vague 5 avant `gnome` (décision de l'utilisateur, 28 sept 2026 ; `vault`, requis par le projet, est fait).

Le dépôt de ce script est public : **aucun nom de client, de dépôt, de domaine ni d'hôte ne doit y figurer** (décision de l'utilisateur, 29 sept 2026 — l'historique en a déjà été nettoyé). Tout ce qui est propre aux projets vit donc dans 1Password.

## What Changes

- Nouveau module **`projets`** (80, groupe `projets`, dépend de `base`, `1password` et `git` ; non graphique) :
  - lit l'**arbre des dépôts** dans l'élément 1Password `op://Imarcom/Projets` (une ligne par dépôt : chemin relatif au dossier personnel, sous `~/projets`, et URL `origin`) et **clone ceux qui manquent**, aux mêmes chemins ; un clone existant n'est jamais modifié ;
  - pour chaque dépôt qu'il vient de cloner et qui prévoit une commande de préparation (`make setup`), déclare l'étape manuelle de la lancer (le projet se prépare lui-même : décision de l'utilisateur, 28 sept 2026) ;
  - ajoute **`bitbucket.org`** aux hôtes SSH connus, depuis la liste publiée par Bitbucket ;
  - installe **`mkcert`** (et `libnss3-tools`) depuis les dépôts d'Ubuntu et pose son **autorité de certification locale** ;
  - ajoute à **`/etc/hosts`** les domaines locaux listés dans le champ `hosts` du même élément, sans toucher aux lignes existantes ;
  - pose l'**accès SSH à l'hôte legacy** depuis l'élément `op://Private/Legacy SSH` : clé publique (et clé privée seulement sans l'agent de 1Password), bloc `Host` gardé dans la note de l'élément, écrit dans `~/.ssh/config.d/projets.conf`, que `~/.ssh/config` inclut.
- Deux **commandes** du runner, hors du menu :
  - **`./setup.sh --snapshot-projets`** (poste de référence) : relève les dépôts git sous `~/projets` et leur `origin`, et écrit l'arbre dans `op://Imarcom/Projets` — la première écriture du script dans 1Password ;
  - **`./setup.sh --pull-projets`** : relit l'arbre, clone ce qui manque, met à jour par avance rapide les clones propres qui suivent une branche distante, ajoute les domaines locaux manquants, et liste ce qu'il a laissé de côté (modifications en cours, branche sans suivi, divergence).

Hors périmètre : `make setup` lui-même et les autres cibles des projets ; le serveur, le second facteur et les copies de données de l'hôte legacy ; la gestion du reste de `~/.ssh/config` ; tout `pull` depuis le module (décision de l'utilisateur : `--pull-projets` seulement).

## Capabilities

### New Capabilities
- `module-projets` : arbre des dépôts dans 1Password, clones, prérequis du poste (`mkcert`, `/etc/hosts`, hôte Bitbucket connu), accès SSH legacy, relevé et mise à jour des projets.

### Modified Capabilities
- `setup-runner` : deux commandes nouvelles, `--snapshot-projets` et `--pull-projets`, à côté de `--list` et `--all`.

## Impact

- Nouveaux : `modules/80-projets.sh`, `tests/test-projets.sh`.
- Modifiés : `setup.sh` (options, aide), `tests/test-run.sh`, `ROADMAP.md`.
- 1Password : lecture de `op://Imarcom/Projets` (`notesPlain`, `hosts`) et de `op://Private/Legacy SSH` ; **écriture** de `notesPlain` de `op://Imarcom/Projets` par `--snapshot-projets` seulement. Éléments à créer par l'utilisateur (clé legacy importée par lui, dans le coffre `Private` que sert l'agent).
- Écritures système : paquets `mkcert` et `libnss3-tools`, autorité `mkcert` dans le magasin du système, lignes de `/etc/hosts`.
- Écritures utilisateur : `~/projets/…`, `~/.ssh/known_hosts`, `~/.ssh/config` (une ligne `Include` en tête), `~/.ssh/config.d/projets.conf`, `~/.ssh/id_ed25519_legacy(.pub)`.
- Réseau : Bitbucket (clés d'hôte, clones), serveurs git des dépôts.
- Validation : WSL (poste de référence : relevé, puis module et `--pull-projets` sur une copie) et VM (poste neuf).
