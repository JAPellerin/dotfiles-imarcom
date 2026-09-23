## Context

Voir `proposal.md`. Le socle fournit `apt_add_repo`, `apt_install`, `pkg_installed`, `run`, `run_sudo`, `ui_spin`. Précédent : `navigateur` (D4) écrit `/etc/default/google-chrome` **avant** le paquet pour que Chrome n'ajoute pas son propre `.list` — vérifié en VM le 21 sept 2026.

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Dépôt | `https://packages.microsoft.com/repos/code`, suite `stable`, composant `main` ; `Release` → 200 ; `code` 1.139.0 publiée |
| Doc, installation manuelle | clé `https://packages.microsoft.com/keys/microsoft.asc` (armurée), `/etc/apt/sources.list.d/vscode.sources` en deb822 |
| Doc, ajout automatique | « preseed `code code/add-microsoft-repo boolean true` » pour que le **paquet** ajoute le dépôt lui-même |
| gnome-keyring, VM Ubuntu 26.04 | installé (dépendance de `ubuntu-desktop-minimal`), avec `libsecret-1-0` et `seahorse` |
| Extensions actuelles | 18, relevées par `code --list-extensions` (VS Code de Windows ; mêmes identifiants côté serveur WSL) |

## Goals / Non-Goals

**Goals :** `code` installé depuis un seul dépôt déclaré par le socle ; les 18 extensions ; un `module_check` qui voit une extension ajoutée à la liste.

**Non-Goals :** réglages, Settings Sync, retrait d'extensions, connexions de comptes.

## Decisions

### D1. Dépôt par `apt_add_repo vscode …`
`apt_add_repo vscode https://packages.microsoft.com/keys/microsoft.asc https://packages.microsoft.com/repos/code stable main` : clé armurée → `/etc/apt/keyrings/vscode.asc`, fichier `vscode.sources` — **le nom même que la doc et le paquet emploient**, si bien qu'un ajout par le paquet malgré D2 écraserait notre fichier au lieu d'en créer un second, et que `apt_add_repo` le verrait différer à la relance (symptôme visible plutôt que doublon silencieux). Architectures : celle de la machine (défaut du helper), là où la doc liste `amd64,arm64,armhf` — sans effet sur un poste amd64.

### D2. Question debconf pré-réglée à « non » avant l'installation
`echo "code code/add-microsoft-repo boolean false" | run_sudo debconf-set-selections` avant `apt_install code`. La doc montre la même clé réglée à `true` pour l'effet inverse ; `false` laisse la déclaration du dépôt au socle. Idempotent (réécrire la même sélection est sans effet). À constater en VM (tâche 2.1) : après installation, `ls /etc/apt/sources.list.d/` ne montre qu'un `vscode.sources`, identique à ce qu'écrit `apt_add_repo`, et une relance ne le réécrit pas.
Alternative : laisser le paquet faire, sans `apt_add_repo` — contraire à la règle du projet (dépôts déclarés par le socle, clé dans `/etc/apt/keyrings/`).

### D3. Extensions : liste versionnée, comparaison insensible à la casse
`config/vscode/extensions.txt` : un identifiant par ligne, `#` pour commenter. Installées : `code --list-extensions`, mises en minuscules. Pour chaque identifiant manquant : `ui_spin "Extension VS Code : <id>" run code --install-extension <id>`. Un échec arrête le module en nommant l'extension (l'état reste constaté : la relance ne refera que celles qui manquent).
`code` s'exécute en utilisateur, jamais avec `sudo` (VS Code refuse de tourner en root sans `--user-data-dir`).

### D4. `module_check`
`pkg_installed code && pkg_installed gnome-keyring` et chaque identifiant de la liste présent dans `code --list-extensions`. `code --list-extensions` lance le binaire (une fraction de seconde) : accepté, c'est la seule source de vérité des extensions — lire `~/.vscode/extensions/extensions.json` serait dépendre d'un format interne.

### D5. Dépendance à `base` seulement
Aucune configuration shell : `code` est dans `/usr/bin`. `MODULE_NEEDS_GUI=1` : l'éditeur n'a pas d'usage sans bureau, et la WSL a le `code` de Windows dans son `PATH` — le module y est sauté, ce qui évite d'installer des extensions dans le mauvais VS Code.

### D6. Tests
`tests/test-vscode.sh` (nouveau) : doublures `dpkg-query`, `run_sudo` (journalise ; simule `apt-get install`, capture l'entrée de `debconf-set-selections`), `apt_add_repo` (compte), faux `code` (`--list-extensions` lit un fichier, `--install-extension` l'ajoute ou échoue pour un identifiant marqué). Cas : première application (sélection debconf posée **avant** `apt-get install`, dépôt, paquets `code` et `gnome-keyring`, 18 extensions) ; réexécution → aucun appel ; extensions partielles → seules les manquantes ; casse différente (`Anthropic.Claude-Code`) → tenue pour installée ; extension hors liste → jamais retirée ; échec d'une extension → module en échec nommant l'identifiant ; commentaires et lignes vides ignorés ; `module_check` sur chaque condition. Plus : `config/vscode/extensions.txt` contient exactement les 18 identifiants décidés.

## Risks / Trade-offs

- [Le paquet ajoute quand même son dépôt malgré D2] → même nom de fichier (D1) : pas de doublon ; constaté en VM avant l'archive, design corrigé sinon.
- [Une extension retirée de la place de marché] → échec nommé ; retirer la ligne de la liste.
- [Les extensions se mettent à jour seules] → comportement de VS Code, voulu.

## Migration Plan

Aucune sur un poste neuf. Retour arrière : `apt remove code`, suppression de `vscode.sources` et `vscode.asc`, `debconf` : `code/add-microsoft-repo` peut rester.
