## Why

Deux modules de la vague 3, `obsidian` et `rocketchat`, s'installent par un `.deb` publié dans les **releases GitHub** de leur éditeur (Obsidian ne publie aucun dépôt apt, Rocket.Chat non plus pour son client de bureau). Le socle sait déjà installer un `.deb` depuis une URL (`apt_install_deb_url`, vague 0) ; il ne sait pas **trouver** cette URL. La règle de la ROADMAP s'applique : un helper employé par deux modules d'une même vague s'écrit **avant** elle, dans un change à part — sinon chacun l'écrirait en double.

Relevé du 23 sept 2026 qui fixe la forme du helper : la release « latest » d'Obsidian (v1.13.8, 21 août 2026) ne contient **qu'un `.apk`** Android ; le dernier `.deb` est dans v1.13.7. Prendre « la dernière release » ne suffit donc pas : il faut **la dernière release qui contient le fichier voulu**.

## What Changes

- **Nouveau `lib/github.sh`**, chargé par `setup.sh` :
  - `github_release_asset_url <propriétaire/dépôt> <motif>` — interroge l'API publique de GitHub, parcourt les releases de la plus récente à la plus ancienne en écartant brouillons et préversions, et imprime l'URL de téléchargement du **premier fichier dont le nom correspond au motif** (expression régulière étendue). Échec nommé si aucune release ne contient un tel fichier ou si l'API ne répond pas.
- Aucun module ne change dans ce change : `obsidian` et `rocketchat` l'emploieront.

Hors périmètre :

- **Jeton GitHub** : l'API publique suffit (60 requêtes par heure et par adresse, un appel par module et par installation).
- **Vérification de somme** des fichiers téléchargés : GitHub ne publie pas de somme pour ces deux projets ; `apt_install_deb_url` contrôle déjà que le fichier est un paquet Debian.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-contract` : nouvelle exigence « URL d'un fichier publié dans les releases GitHub ».

## Impact

- Nouveaux `lib/github.sh` et `tests/test-github.sh` ; `setup.sh` charge le nouveau fichier.
- Réseau : `api.github.com`, seulement quand un module l'appelle (jamais dans `module_check`). Les tests restent hors ligne.
- Docs : `CLAUDE.md` (liste des helpers), `ROADMAP.md` (`socle-github` avant `obsidian` et `rocketchat` ; `vpn` en installation seule, configuration reportée).
