## Why

Relevé en VM à la validation de `projets` (29 sept 2026) : quand le module a posé l'autorité de certification locale de `mkcert`, **aucune base de certificats de navigateur n'existait** — Brave avait tourné (Brave Sync) sans créer `~/.pki/nssdb`, Firefox n'avait jamais été lancé. `mkcert -install` a donc seulement rempli le magasin du système (« no Firefox and/or Chrome/Chromium security databases found »), et le module ne revient jamais sur ce point : les navigateurs ne font pas confiance aux certificats de développement des projets (proxy https local). De plus, `mkcert` 1.4.4 ne cherche les profils Firefox qu'aux emplacements historiques ; Firefox 157 n'a pas encore créé le sien, son emplacement est à relever.

## What Changes

- Le module `projets` crée la base de certificats partagée de Chromium, Brave et Chrome (`~/.pki/nssdb`) lorsqu'elle n'existe pas, pour qu'elle reçoive l'autorité **avant** que le navigateur en ait besoin (décision de l'utilisateur, 29 sept 2026 : « auto-réparation »).
- Il ajoute l'autorité de `mkcert` à **chaque base de certificats de navigateur présente** (base partagée et profils Firefox, emplacements relevés en VM), par `certutil`, lui-même, sans dépendre de ce que `mkcert` sait trouver.
- `module_check` exige l'autorité dans chaque base présente (lecture seule) : un profil Firefox créé plus tard rend le module « à faire », et valider le menu au passage suivant l'y ajoute.

Hors périmètre : stratégie d'entreprise des navigateurs pour les certificats ; certificats des projets eux-mêmes (`make proxy-cert`) ; Chrome et Firefox en snap.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-projets` : l'autorité locale est aussi reconnue des navigateurs ; l'état du module en tient compte.

## Impact

- Modifiés : `modules/80-projets.sh`, `tests/test-projets.sh`.
- Écritures utilisateur : `~/.pki/nssdb` (créée si absente), bases `cert9.db` des profils Firefox (ajout d'un certificat d'autorité). Aucune écriture système nouvelle.
- Outils : `certutil` (paquet `libnss3-tools`, déjà installé par le module), `openssl` pour l'empreinte (paquet de base) — à confirmer en tâche 0.
- Validation en VM : Brave et Firefox lancés, puis page https du proxy local sans avertissement.
