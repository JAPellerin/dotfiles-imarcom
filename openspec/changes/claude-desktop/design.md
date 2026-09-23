## Context

Voir `proposal.md`. Le socle fournit `apt_add_repo`, `apt_install`, `pkg_installed`, `install_system_file` (copie idempotente vers `/etc`, comparée par `cmp`), `manual_step`, et — **après `socle-groupes`** — `user_in_group`, `ensure_user_in_group`, `group_relogin_step`. Précédent : `navigateur` D4 (`/etc/default/google-chrome` posé avant le paquet, vérifié en VM le 21 sept 2026).

Relevés du 23 sept 2026 (doc « Claude Desktop on Linux (beta) » et dépôt) :

| Fait | Mesure |
|---|---|
| Dépôt | `https://downloads.claude.ai/claude-desktop/apt/stable`, suite `stable`, composant `main`, `amd64 arm64` ; `Release` daté du 23 sept 2026 ; `claude-desktop` 1.17282.0 (2.7032.0 à la contre-vérification, même jour) |
| Clé | `https://downloads.claude.ai/claude-desktop/key.asc` (armurée), empreinte `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE` — la même que Claude Code |
| Doc, dépôt | `.list` d'une ligne dans `/etc/apt/sources.list.d/claude-desktop.list`, clé dans `/usr/share/keyrings/` |
| Doc, paquet | « Installing the `.deb` also registers Anthropic's apt repository at `/etc/apt/sources.list.d/claude-desktop.list` » ; pour l'éviter : `/etc/default/claude-desktop` avec `CLAUDE_DESKTOP_ADD_REPO="false"` ; la désinstallation retire ce que le paquet a enregistré |
| Cowork | QEMU/UEFI/`virtiofsd` en **recommandations** du paquet ; groupe `kvm` exigé (`/dev/vhost-vsock` n'est ouvert qu'aux membres) ; réouverture de session |
| Dépendances | GTK3, NSS, `xdg-desktop-portal` (+ `-gnome`/`-gtk`), `libsecret-1-0`… — présentes sur Ubuntu Desktop |
| VM Hyper-V | groupe `kvm` présent (`kvm:x:991:`), **pas de `/dev/kvm`** |

## Goals / Non-Goals

**Goals :** l'application depuis un seul dépôt déclaré par le socle ; Cowork prêt côté poste (paquets, groupe) ; connexion signalée.

**Non-Goals :** virtualisation matérielle, `vhost_vsock`, réglages de l'application.

## Decisions

### D1. `/etc/default/claude-desktop` posé avant le paquet
`config/claude-desktop/claude-desktop.default` (versionné) contient `CLAUDE_DESKTOP_ADD_REPO="false"`, copié par `install_system_file` vers `/etc/default/claude-desktop` **avant** `apt_install`. Le paquet relit ce fichier à chaque mise à jour : il doit rester en place, d'où sa présence dans `module_check` (D5).
**Vérifié dans le `postinst` du paquet 2.7032.0 (contre-vérification, 23 sept 2026).** Le fichier est lu à chaque `configure` (installation et mise à jour), **analysé et non exécuté** : commentaires, `export` et guillemets tolérés, seules les valeurs `true`/`false` comptent — notre fichier est reconnu tel quel. Avec `false`, le script ne touche pas du tout à `/etc/apt` : ni `claude-desktop.list`, ni `/etc/apt/apt.conf.d/50claude-desktop`. Le paquet ne livre pas `/etc/default/claude-desktop` comme conffile : le poser avant ne provoque aucune question de `dpkg`. Sa clé `/usr/share/keyrings/claude-desktop-archive-keyring.asc` est écrite dans tous les cas — sans effet, notre `.sources` pointe sur `/etc/apt/keyrings/claude-desktop.asc`.
**Conséquence acceptée (décision de l'utilisateur, 23 sept 2026) : pas de mises à jour automatiques.** `50claude-desktop` inscrit le dépôt d'Anthropic auprès d'`unattended-upgrades` ; sans lui, Claude Desktop se met à jour par `apt upgrade` ou par le programme de mise à jour d'Ubuntu (qui propose les mises à jour de tous les dépôts apt), comme Docker, VS Code et Brave. Alternative écartée : versionner notre propre `50claude-desktop` — un fichier de plus, calqué sur un format interne d'Anthropic.
Alternative rejetée : laisser le paquet déclarer son dépôt et se passer d'`apt_add_repo` — clé hors de `/etc/apt/keyrings/`, format `.list`, contraire à la règle du projet.

### D2. Dépôt par `apt_add_repo claude-desktop …`
`apt_add_repo claude-desktop https://downloads.claude.ai/claude-desktop/key.asc https://downloads.claude.ai/claude-desktop/apt/stable stable main` → `/etc/apt/keyrings/claude-desktop.asc` et `claude-desktop.sources`. Le nom diffère du `.list` du paquet : **si D1 ne suffisait pas**, on verrait deux déclarations et un avertissement « configured multiple times » d'apt — c'est ce que la validation en VM regarde (tâche 2.1).

### D3. `apt_install claude-desktop`, recommandations comprises
`apt-get install` installe les recommandations par défaut : QEMU, UEFI et `virtiofsd` arrivent avec le paquet, comme la doc le décrit. Aucun paquet nommé en plus.

### D4. Cowork : helpers de `socle-groupes`
`ensure_user_in_group kvm` puis `group_relogin_step kvm`. Aucune vérification de `/dev/kvm` : la présence de la virtualisation est une affaire de matériel, que l'application signale elle-même ; le module ne doit ni échouer ni la promettre.

### D5. Connexion et `module_check`
Connexion : **dans `module_install`**, si `claude-desktop` était absent avant `apt_install` et que l'installation réussit, `manual_step "Ouvrir Claude (menu des applications) et se connecter avec le compte Anthropic."`. Pas de variable transmise à `module_configure` : le runner lance `module_install` et `module_configure` dans deux sous-shells distincts (`module_call`, `lib/module.sh`), une variable posée dans l'un est perdue dans l'autre. `manual_step` écrit dans un fichier, qui survit au sous-shell. On ne cherche pas où l'application range sa session : chemin interne, non documenté.
`module_check` : `pkg_installed claude-desktop` **et** `cmp -s config/claude-desktop/claude-desktop.default /etc/default/claude-desktop` (lisible sans `sudo`) **et** `user_in_group kvm`.

### D6. Dépendance à `base` seulement ; prérequis `socle-groupes`
`MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1`. `socle-groupes` n'est pas un module mais du code de `lib/` : c'est un **ordre d'implémentation** (ce change après lui), pas une dépendance du runner.

### D7. Tests
`tests/test-claude-desktop.sh` (nouveau) : doublures `dpkg-query`, `getent`, `id`, `run_sudo` (journalise ; simule `apt-get install`, `usermod`, `install`/copie vers un `/etc` du `$TEST_TMP`), `apt_add_repo` (compte) ; chemin de `/etc/default/claude-desktop` surchargeable. Cas : première application (réglage posé **avant** `apt-get install`, dépôt, paquet, `usermod -aG kvm`, étape de session nommant `kvm`, étape de connexion) ; réexécution → aucun appel ; réglage supprimé → `module_check` à faire, rétabli ; réglage au contenu différent → rétabli ; déjà membre de `kvm` → pas de `usermod` ; paquet déjà là → pas d'étape de connexion ; installation du paquet en échec → pas d'étape de connexion ; `module_install` et `module_configure` appelés chacun dans un sous-shell, comme par le runner → l'étape de connexion figure bien au fichier des étapes manuelles ; `module_check` sur chaque condition.

## Risks / Trade-offs

- [Linux en bêta : le mécanisme de D1 change] → constaté en VM avant l'archive ; `apt_add_repo` ferait voir un doublon (D2).
- [Le groupe `kvm` donne accès à la virtualisation] → exigé par la doc de l'application ; choix de l'utilisateur.
- [Recommandations lourdes (QEMU)] → voulues pour Cowork ; la doc les installe ainsi.
- [Claude Desktop hors des mises à jour automatiques] → conséquence du réglage de D1 (le paquet n'écrit pas `50claude-desktop`) ; mises à jour par `apt upgrade` ou le programme de mise à jour d'Ubuntu, décision de l'utilisateur.

## Migration Plan

Aucune sur un poste neuf. Retour arrière (doc) : `apt remove claude-desktop`, puis `claude-desktop.sources`, `claude-desktop.asc` et `/etc/default/claude-desktop` ; `gpasswd -d $USER kvm` si voulu.
