## Why

Thunderbird est le client de courriel et d'agenda de l'utilisateur (courriel et agendas Google, selon la ROADMAP). Sur Ubuntu 26.04, le paquet `thunderbird` n'est qu'un **paquet de transition vers le snap** (`2:1snap1-0ubuntu5`, relevé en VM le 23 sept 2026) — la même situation que Firefox — et, contrairement à Firefox, **le dépôt apt de Mozilla ne publie pas Thunderbird** (aucun paquet `thunderbird` dans `packages.mozilla.org`). Le seul format officiel de Mozilla pour Linux est l'**archive `.tar.xz`**.

## What Changes

- **Module `thunderbird`** (`modules/62-thunderbird.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - **archive officielle de Mozilla**, en français, par l'adresse de téléchargement de Mozilla (`download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=fr`) ;
  - **installée dans le dossier personnel** (`~/.local/share/thunderbird`), sans `sudo`, pour que la **mise à jour intégrée de Thunderbird fonctionne** — installé sous `/opt`, le dossier appartiendrait à root et la doc de Mozilla prévoit alors une réinstallation manuelle à chaque version ;
  - commande `thunderbird` dans `~/.local/bin` et **lanceur** `~/.local/share/applications/thunderbird.desktop`, tiré du fichier `.desktop` que publie Mozilla, chemins adaptés au dossier d'installation ;
  - étape manuelle à la première installation : ajouter les comptes de courriel et les agendas Google dans Thunderbird.

Décisions de l'utilisateur (23 sept 2026) : **archive de Mozilla** (ni le snap d'Ubuntu, ni le PPA non officiel `mozillateam`) ; **méthode « dossier personnel »**.

Hors périmètre :

- **Comptes de courriel et agendas** : connexion OAuth à Google, faite dans Thunderbird (étape manuelle).
- **Client de courriel par défaut** (`mailto:`) : à ajouter si l'utilisateur le demande.
- **Paquet de transition snap d'Ubuntu** : il n'est pas installé sur un poste neuf (vérifié en VM) ; le module ne l'installe pas et n'a rien à retirer.

## Capabilities

### New Capabilities
- `module-thunderbird` : le module `thunderbird` — archive officielle de Mozilla dans le dossier personnel (mise à jour intégrée active), commande et lanceur, comptes en étape manuelle.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/62-thunderbird.sh`, `config/thunderbird/thunderbird.desktop` (gabarit), `tests/test-thunderbird.sh`.
- Fichiers utilisateur : `~/.local/share/thunderbird/` (≈ 300 Mio décompressés), `~/.local/bin/thunderbird`, `~/.local/share/applications/thunderbird.desktop`. **Aucune écriture système, aucun `sudo`.**
- Réseau : `download.mozilla.org` (≈ 80 Mio). Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL ; validation en VM.
- Docs : `ROADMAP.md` (`thunderbird` fait).
