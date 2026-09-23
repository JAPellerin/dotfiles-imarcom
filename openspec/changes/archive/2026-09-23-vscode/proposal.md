## Why

VS Code est l'éditeur de l'utilisateur. Aujourd'hui il tourne sous Windows et travaille dans la WSL ; sur le nouveau laptop Ubuntu, il doit être installé nativement, avec les extensions dont l'utilisateur se sert — sans quoi chaque poste neuf demande une demi-heure de clics dans la place de marché.

## What Changes

- **Module `vscode`** (`modules/51-vscode.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - **VS Code depuis le dépôt apt de Microsoft** (`packages.microsoft.com/repos/code`), déclaré par `apt_add_repo`, selon la procédure « manuelle » de la doc ;
  - **le paquet n'ajoute pas son propre dépôt** : sa question debconf `code/add-microsoft-repo` est pré-réglée à « non » avant l'installation — sinon il écrirait lui-même `vscode.sources`, le même piège que Chrome et son `repo_add_once` ;
  - **`gnome-keyring`** passé à `apt_install` avec le paquet : VS Code y range ses jetons (GitHub, Claude). Il est déjà présent sur Ubuntu 26.04 (dépendance de `ubuntu-desktop-minimal`, vérifié en VM) ; le nommer rend la dépendance visible et ne coûte rien ;
  - **extensions** : une liste versionnée `config/vscode/extensions.txt` (un identifiant par ligne), installées par `code --install-extension` — seulement celles qui manquent.

Décisions de l'utilisateur (23 sept 2026) :

- **Les 18 extensions** relevées dans son VS Code actuel, telles quelles : `anthropic.claude-code`, `atlassian.atlascode`, `bradlc.vscode-tailwindcss`, `dbaeumer.vscode-eslint`, `eamodio.gitlens`, `graphql.vscode-graphql`, `graphql.vscode-graphql-syntax`, `mechatroner.rainbow-csv`, `ms-azuretools.vscode-containers`, `ms-ossdata.vscode-pgsql`, `ms-playwright.playwright`, `ms-vscode.makefile-tools`, `redhat.vscode-yaml`, `shd101wyy.markdown-preview-enhanced`, `streetsidesoftware.code-spell-checker`, `streetsidesoftware.code-spell-checker-french`, `vitest.explorer`, `yzhang.markdown-all-in-one`.
- **Pas de `settings.json` versionné** : VS Code réécrit ce fichier depuis son interface (un lien symbolique écrirait dans le dépôt, ou serait remplacé) ; le `settings.json` actuel (37 lignes) est surtout propre à Windows. À ajouter quand des réglages Linux seront à conserver.

Hors périmètre :

- **Settings Sync** de VS Code — non utilisé aujourd'hui.
- **Retrait d'extensions** absentes de la liste — une extension ajoutée à la main reste.
- **Connexion aux comptes** (GitHub, Atlassian, Claude) dans les extensions — faite dans l'interface au premier usage.

## Capabilities

### New Capabilities
- `module-vscode` : le module `vscode` — VS Code depuis le dépôt de Microsoft sans dépôt en double, trousseau GNOME, extensions d'une liste versionnée.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/51-vscode.sh`, `config/vscode/extensions.txt`, `tests/test-vscode.sh`.
- Écritures système (avec `sudo`) : `/etc/apt/keyrings/vscode.asc`, `/etc/apt/sources.list.d/vscode.sources`, sélection debconf `code/add-microsoft-repo`, paquets apt.
- Fichiers utilisateur : `~/.vscode/extensions/` (par VS Code).
- Réseau : `packages.microsoft.com`, place de marché des extensions. Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL (où `code` est celui de Windows) ; validation en VM.
- Docs : `ROADMAP.md` (`vscode` fait).
