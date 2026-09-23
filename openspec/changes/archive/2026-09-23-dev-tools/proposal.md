## Why

Deux outils en ligne de commande font partie du travail quotidien de l'utilisateur : **Claude Code** (`claude`) et la **CLI Atlassian Teamwork Graph** (`twg`), qui donne accès à Jira, Confluence et Bitbucket. Tous deux sont déjà installés dans la WSL, à la main ; sur un poste neuf, rien ne les pose.

La ROADMAP rangeait ce module **après `node`**, au motif que « Claude Code et twg CLI passent par npm ». C'est faux, vérifié le 23 sept 2026 : Claude Code a un installateur natif (la méthode recommandée par sa doc ; `installMethod: native` dans la WSL), et twg est un binaire autonome compilé avec Bun, posé par l'installateur public d'Atlassian (`install.json` : `direct-public-installer`). **`dev-tools` ne dépend pas de `node`** : la vague 2 n'a aucune dépendance interne.

## What Changes

- **Module `dev-tools`** (`modules/42-dev-tools.sh`, groupe `dev`, dépend de `base` et `shell`, sans session graphique requise) :
  - **Claude Code** par l'**installateur natif de sa documentation** (`https://claude.ai/install.sh`) — choix de l'utilisateur : `~/.local/bin/claude`, mise à jour automatique en arrière-plan comme le prévoit la doc ;
  - **twg** par l'**installateur public d'Atlassian** (`https://teamwork-graph.atlassian.com/cli/install`) avec `--skip-login` : `~/.local/bin/twg` ;
  - **connexions en étapes manuelles** : `twg login` (autorisation OAuth par appareil, interactive par principe), et la connexion de Claude Code au premier lancement, déclarées au résumé final quand elles ne sont pas faites.
- Les deux installateurs sont lancés avec **`~/.local/bin` en tête du `PATH`**, pour qu'ils ne cherchent pas à l'ajouter eux-mêmes dans `~/.zshrc` ou `~/.bashrc` — `~/.zshrc` est un lien vers le dépôt.

Décisions de l'utilisateur (23 sept 2026) :

- **Claude Code : la méthode de la doc**, l'installateur natif (et non le dépôt apt, qui existe aussi).
- **twg : connexion manuelle**, pas de parcours guidé ; le jeton Bitbucket (`twg setup bitbucket`) est hors périmètre.

Hors périmètre :

- **Réglages de Claude Code** (`~/.claude/settings.json`, canal de mise à jour, `autoUpdates`) — préférences personnelles ; le module n'y touche pas.
- **Plugins, skills et serveurs MCP** de Claude Code ; **skills de twg** (`twg skills`).
- **Claude Desktop** — module `claude-desktop`.

## Capabilities

### New Capabilities
- `module-dev-tools` : le module `dev-tools` — Claude Code et twg par leurs installateurs officiels, sans modifier les fichiers du shell, connexions déclarées comme étapes manuelles.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/42-dev-tools.sh` et `tests/test-dev-tools.sh`.
- Fichiers créés hors dépôt : `~/.local/bin/claude` (lien vers `~/.local/share/claude/versions/<version>`), `~/.local/bin/twg`, `~/.config/twg/install.json`. Aucune écriture système, aucun `sudo`.
- Réseau : `claude.ai`, `downloads.claude.ai`, `teamwork-graph.atlassian.com`. Les tests restent hors ligne.
- **Dans la WSL** : Claude Code 2.1.280 et twg 1.3.1 déjà là, connexions faites → le module doit s'y déclarer « déjà fait » sans rien relancer.
- Docs : `ROADMAP.md` (`dev-tools` fait ; dépendance à `node` retirée, vague 2 sans dépendance interne).
