## Context

Dépôt vide. Cible : laptop de travail Ubuntu 26.04 LTS avec GNOME ; développement et tests partiels dans WSL (Ubuntu 26.04, sans GNOME), tests complets dans une VM Hyper-V avec snapshot « vierge ». Contraintes héritées de `~/setup-sudo.sh` : installs selon la doc officielle des éditeurs, dépôts apt au format deb822 (`.sources`) avec clé dans `/etc/apt/keyrings/`, `set -euo pipefail`, commentaires en français. Voir `proposal.md` pour la motivation.

## Goals / Non-Goals

**Goals:**
- Un socle que chaque module futur réutilise sans le modifier : découverte, menu, dépendances, sudo, journal, helpers.
- Zéro dépendance non résolue par le bootstrap lui-même (`git`, `gum`).
- Testable module par module (`setup.sh <module>`) et sans GNOME.

**Non-Goals:**
- Portabilité hors Ubuntu 26.04 (pas de Debian, Fedora, macOS).
- Désinstallation / rollback des modules.
- Exécution non interactive complète (`--yes`) : possible plus tard, pas dans le socle.
- Profils de sélection (`--profile minimal`) : la présélection des modules non faits couvre le cas « tout installer » ; voir `ROADMAP.md`.

## Decisions

### D1. Bash + gum plutôt qu'une CLI Node/Python
Bash est le langage naturel des commandes d'installation (apt, curl, gpg) et tourne sans rien sur une machine vierge ; `gum` apporte les menus, confirmations, spinners et saisies dignes de `create-vite`. Alternatives : Node + `@clack/prompts` (belle UX mais Node à installer d'abord, double couche), Python + `questionary` (idem), `whiptail` (aucune dépendance mais UX datée). `gum` 0.17 est dans les dépôts Ubuntu 26.04 : `apt install gum`, sans dépôt Charm — plus simple et cohérent avec « apt d'abord ».

### D2. Bootstrap `curl | bash` → clone HTTPS → `exec setup.sh`
Dépôt public, aucune donnée sensible (tout secret vit dans 1Password), donc clone HTTPS sans authentification. Le bootstrap n'a pas accès au terminal sur `stdin` (occupé par le pipe) : on relance avec `exec bash setup.sh < /dev/tty` pour rendre l'interactivité. Alternative rejetée : bootstrap qui télécharge un tarball (pas de `git pull` possible ensuite, et le dépôt doit rester à jour sur la machine pour relancer des modules).

### D3. Runner en utilisateur, `sudo -v` + keepalive
Le précédent script tournait en root ; ici oh-my-zsh, nvm, `op signin`, `.desktop` et les fichiers de config appartiennent à l'utilisateur. `setup.sh` refuse root, appelle `sudo -v` au démarrage puis rafraîchit le ticket en tâche de fond (`while true; do sudo -n true; sleep 60; done &`, tué à la sortie via `trap`). Les commandes privilégiées passent par un helper `run_sudo`.

### D4. Contrat de module : fichier sourcé, métadonnées + 3 fonctions
Un module = `modules/NN-nom.sh` sourcé dans un sous-shell par le runner, exposant `MODULE_NAME/DESC/GROUP/DEPS[/NEEDS_GUI]` et `module_check/install/configure`. Sourcer dans un sous-shell isole les fonctions et variables d'un module à l'autre (deux modules peuvent définir `module_install` sans conflit). L'état n'est pas persisté dans un fichier : `module_check` est la seule source de vérité, ce qui garantit qu'un état réel divergent (paquet désinstallé à la main) est bien détecté. Alternative rejetée : fichier d'état `~/.local/state/dotfiles/done` (ment dès qu'on touche la machine à la main).

### D5. Découverte et affichage
Le runner charge chaque module une première fois pour lire les métadonnées et appeler `module_check` (rapide, sans effet de bord), construit la liste `[groupe] nom — description — état`, puis affiche `gum choose --no-limit --selected=<modules non faits>`. Les modules « déjà faits » sont visibles, non présélectionnés : `Entrée` sans rien toucher installe tout ce qui manque. `gum choose` n'offre pas d'en-têtes non sélectionnables, d'où le préfixe `[groupe]` (valeurs et découpage dans `ROADMAP.md`) ; l'ordre d'affichage suit le préfixe `NN`. `--list` affiche la même table via `gum table` ou un `printf` aligné.

### D6. Ordonnancement
Tri topologique simple sur `MODULE_DEPS` (DFS avec détection de cycle), avec deux règles : les dépendances d'abord, puis `1password` avancé devant tout module non-dépendance. Le préfixe `NN` du nom de fichier ne sert qu'à l'affichage et à départager les ex æquo.

### D7. Journal
`exec` d'un `tee` : stdout/stderr des commandes vont dans `~/.local/state/dotfiles/setup-<date>.log` ; à l'écran, seuls les messages `log_*` et les spinners `gum spin`. Les secrets lus par `op_read` ne transitent jamais par le journal (le helper n'écrit rien et les modules doivent les passer par variable, jamais par `echo`).

### D8. 1Password : app + CLI, même dépôt
Le dépôt apt `downloads.1password.com/linux/debian/<arch>` sert les deux paquets (`1password`, `1password-cli`), avec la politique `debsig` demandée par la doc officielle. L'app n'est installée que si `$DISPLAY`/`$WAYLAND_DISPLAY` existe (`has_gui`). Connexion : intégration app → CLI si l'app est là (déverrouillage par l'app, agent SSH), sinon `op account add` interactif. La session issue de `op signin` est exportée dans l'environnement du runner pour les modules suivants (`eval "$(op signin)"`).

### D9. Détection d'environnement graphique
`has_gui()` : vrai si `$XDG_SESSION_TYPE` est `x11`/`wayland` ou si `$DISPLAY`/`$WAYLAND_DISPLAY` est défini ; faux sinon (WSL, TTY, SSH). Les modules `MODULE_NEEDS_GUI=1` sont listés « non disponible ici » et sautés sans échec.

### D10. Helper apt en deb822
`apt_add_repo <nom> <url-clé> <url-dépôt> <suite> <composants>` écrit la clé dans `/etc/apt/keyrings/<nom>.asc` (ou `.gpg` si dearmor requis) et `/etc/apt/sources.list.d/<nom>.sources` au format deb822, comme le fait Ubuntu 26.04 nativement et comme `setup-sudo.sh` le faisait pour Docker. Idempotent : ne réécrit pas si le contenu est identique, et ne relance `apt update` que si un dépôt a changé.

## Risks / Trade-offs

- [`curl | bash` perd le terminal] → `exec ... < /dev/tty` dans le bootstrap ; vérifié en VM dès la première tâche.
- [`gum` absent dans la phase pré-bootstrap] → ces quelques lignes utilisent `echo` simple ; acceptable.
- [Intégration app → CLI de 1Password impossible sans clic dans l'interface] → étape guidée par le module (ouvre l'app, explique, attend confirmation) ; repli `op account add` en terminal. Documenté comme étape manuelle.
- [Sourcer un module en sous-shell empêche de remonter des variables] → les seuls retours nécessaires (code de sortie, étapes manuelles) passent par le code de retour et un fichier temporaire d'étapes manuelles.
- [`apt upgrade` au premier lancement peut être long et surprendre] → confirmé par un `gum confirm` dans `base`, activé par défaut.
- [Pas de VM avant le premier test réel] → les tâches prévoient la création de la VM Hyper-V avec snapshot avant la validation de bout en bout.

## Open Questions

- ~~URL exacte du dépôt~~ Tranché le 15 sept : GitHub `JAPellerin/dotfiles-imarcom`, clone `https://github.com/JAPellerin/dotfiles-imarcom.git`, raw `https://raw.githubusercontent.com/JAPellerin/dotfiles-imarcom/main/bootstrap.sh`, constantes dans `bootstrap.sh`. Le dossier local reste `~/dotfiles`.
- Nom du coffre 1Password et convention de nommage des items (`op://<coffre>/<item>/<champ>`) : décidé au premier module consommateur (`git`).
