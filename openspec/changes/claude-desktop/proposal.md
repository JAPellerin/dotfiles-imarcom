## Why

Claude Desktop — Chat, Cowork et Claude Code dans une application de bureau — a une version Linux officielle (bêta) depuis l'été 2026, distribuée par un **dépôt apt d'Anthropic** qui prend en charge Ubuntu 26.04. Sur le nouveau laptop, l'utilisateur veut l'application installée et prête, Cowork compris.

## What Changes

- **Module `claude-desktop`** (`modules/52-claude-desktop.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - **dépôt apt d'Anthropic** (`downloads.claude.ai/claude-desktop/apt/stable`) déclaré par `apt_add_repo`, puis `apt_install claude-desktop` — les paquets recommandés (QEMU, UEFI, `virtiofsd`, dont Cowork a besoin) arrivent avec, comme le prévoit la doc ;
  - **le paquet n'ajoute pas son propre dépôt** : `/etc/default/claude-desktop` (`CLAUDE_DESKTOP_ADD_REPO="false"`, réglage documenté) est posé **avant** l'installation — même mécanisme que `/etc/default/google-chrome` pour Chrome ;
  - **Cowork** : utilisateur inscrit au groupe `kvm` (exigé par la doc pour `/dev/kvm` et `/dev/vhost-vsock`), avec l'étape « rouvrir la session » tant que la session ne porte pas le groupe — par les helpers de `socle-groupes` ;
  - **connexion** : étape manuelle (« ouvrir Claude et se connecter ») lors de la première installation.

Décision de l'utilisateur (23 sept 2026) : **préparer Cowork** (groupe `kvm`).

**Prérequis : le change `socle-groupes`** (helpers `ensure_user_in_group`, `user_in_group`, `group_relogin_step`) doit être fait avant ce module. `node`, `dev-tools` et `vscode` n'en dépendent pas.

Hors périmètre :

- **Virtualisation matérielle** (réglage du micrologiciel) et module noyau `vhost_vsock` : hors de portée d'un script de poste ; l'application les signale elle-même dans l'onglet Cowork. Dans la VM Hyper-V de test, `/dev/kvm` n'existe pas (pas de virtualisation imbriquée) : Cowork n'y fonctionnera pas, sans conséquence sur le module.
- **Réglages de l'application**, connecteurs, extensions.
- **Claude Code en ligne de commande** — module `dev-tools`.

## Capabilities

### New Capabilities
- `module-claude-desktop` : le module `claude-desktop` — application depuis le dépôt apt d'Anthropic sans dépôt en double, préparation de Cowork (groupe `kvm`), connexion en étape manuelle.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/52-claude-desktop.sh`, `config/claude-desktop/claude-desktop.default`, `tests/test-claude-desktop.sh`.
- Écritures système (avec `sudo`) : `/etc/default/claude-desktop`, `/etc/apt/keyrings/claude-desktop.asc`, `/etc/apt/sources.list.d/claude-desktop.sources`, paquets apt (avec recommandations), appartenance au groupe `kvm`.
- Réseau : `downloads.claude.ai`. Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL ; validation en VM, **après** `socle-groupes`.
- Docs : `ROADMAP.md` (`claude-desktop` fait).
