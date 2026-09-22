## Context

Voir `proposal.md`. État du socle au 22 sept 2026 : `apt_install` (paquets manquants seulement), `pkg_installed`, `link_config` / `config_linked`, `run`, `log_*`, `ui_spin`, et la convention des fragments posée par la vague 0 (`openspec/specs/config-files/spec.md`). `config/shell/commonrc` met déjà `~/.local/bin` en tête du `PATH` et charge en dernier `~/.commonrc.d/*.sh`. `config/shell/zshrc` active `zoxide` et `fzf` sous garde `command -v` (lignes 123-124) ; `config/shell/bashrc-extra.sh` ne le fait pas.

Relevé sur Ubuntu 26.04.1 (resolute), la même version que la machine cible : les sept paquets sont dans les dépôts (`ripgrep` 15.1.0, `fd-find` 10.3.0, `fzf` 0.67.0, `bat` 0.25.0, `zoxide` 0.9.8, `lazygit` 0.57.0, `postgresql-client` 18). Les descriptions des paquets confirment le renommage : `batcat` « because of a file name clash with another Debian package », `fd` → `fdfind` « because of a file name clash ». `fzf` ≥ 0.48 fournit `fzf --bash` et `fzf --zsh`.

## Goals / Non-Goals

**Goals :** un module entièrement vérifiable dans la WSL ; une configuration qui marche dans les deux shells **et** hors shell interactif ; servir de modèle propre au dépôt d'un fragment, puisque c'est le premier.

**Non-Goals :** choisir des thèmes ; configurer `lazygit` ou `psql` ; ajouter des outils que le `ROADMAP.md` ne liste pas.

## Decisions

### D1. `bat` et `fd` par des liens dans `~/.local/bin`, pas par des alias
Un alias (`alias bat=batcat` dans le fragment) n'existe que dans un shell interactif : il ne sert ni dans un script, ni dans un `xargs`, ni dans l'aperçu que `fzf` lance dans un sous-processus — or cet aperçu appelle justement `bat`. Le lien `~/.local/bin/bat → /usr/bin/batcat` fonctionne partout, sans dépendre du shell.
Alternatives rejetées : les alias (cassent l'aperçu `fzf`, cas concret et immédiat) ; `dpkg-divert` ou un lien dans `/usr/local/bin` (écriture système avec `sudo` pour un confort utilisateur, et conflit potentiel avec un vrai paquet `bat` futur).
Garde-fou : si `~/.local/bin/bat` existe et n'est pas le lien attendu, le module le **laisse intact** et le signale (`log_warn`). Le poste peut avoir un vrai binaire installé à la main ; l'écraser serait une perte silencieuse. `module_check` renvoie alors « à faire », ce qui est exact : la configuration attendue n'est pas en place.

### D2. Le lien vise le binaire réel, résolu à l'exécution
La cible est lue par `command -v batcat` plutôt qu'écrite en dur (`/usr/bin/batcat`) : le chemin appartient au paquet, pas au script, et un binaire déplacé par une version future d'Ubuntu n'oblige pas à corriger le module. Si la commande est introuvable après l'installation, le module échoue en la nommant — c'est le symptôme d'un paquet qui a changé de forme, pas quelque chose à contourner en silence.

### D3. Le fragment porte `fzf`, et seulement lui
Contenu de `config/cli-tools/commonrc.sh` (POSIX, commun aux deux shells) :
```sh
FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always {}"'
export FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_DEFAULT_OPTS
```
`fd --hidden --exclude .git` : chercher dans les fichiers cachés est l'attente courante dans un dépôt, sans se noyer dans `.git`. `bat` dans l'aperçu est la raison d'être de D1.
Rien d'autre ne va dans le fragment : `ripgrep`, `lazygit` et `psql` n'ont besoin d'aucune variable, et `zoxide` comme `fzf` s'initialisent par shell (D4).
Le fragment MUST NOT contenir de garde `command -v` : le lien n'existe que si le module est installé, ce qui est précisément l'intérêt d'un lien par fragment (`openspec/specs/config-files/spec.md`).

### D4. Initialisation propre à chaque shell : `bashrc-extra.sh` rattrape `zshrc`
`fzf` et `zoxide` s'initialisent par une forme différente selon le shell (`fzf --bash` / `fzf --zsh`, `zoxide init bash` / `zoxide init zsh`) : cela ne peut pas vivre dans un fragment POSIX commun. `zshrc` le fait déjà ; on ajoute les deux lignes équivalentes à `bashrc-extra.sh`, sous la même garde `command -v`.
Pourquoi ici et pas dans le module `shell` : ces lignes n'ont d'effet que si `cli-tools` a installé les outils, et c'est ce module qui rend l'asymétrie visible. Elle est antérieure (constatée le 22 sept 2026 en écrivant la vague 0) mais n'avait aucun effet tant que ni `fzf` ni `zoxide` n'étaient installés.

### D5. `module_check`
Vrai si : les sept paquets sont installés (`pkg_installed`) **et** `~/.local/bin/bat` et `~/.local/bin/fd` sont les liens attendus **et** `config_linked config/cli-tools/commonrc.sh "$HOME/.commonrc.d/cli-tools.sh"`. Tout est constaté, rien n'est mémorisé. Les lignes de `bashrc-extra.sh` ne sont pas vérifiées ici : ce fichier appartient au module `shell`, dont le `module_check` couvre déjà le lien.

### D6. Tests (`tests/test-cli-tools.sh`)
`HOME` isolé, `PATH` préfixé d'un dossier de doublures, aucune installation réelle :
- `dpkg-query` doublé, paramétrable par un fichier marqueur, pour simuler « rien d'installé », « partiellement installé », « tout installé » ;
- `run_sudo` doublé comme dans `tests/test-apt.sh` (les `apt-get` sont comptés, pas exécutés) ;
- faux `batcat` et `fdfind` exécutables dans le dossier des doublures, pour que `command -v` les trouve et que les liens pointent quelque part de réel.
Cas : première application (sept paquets passés à apt, deux liens créés et exécutables, fragment lié) ; installation partielle (seuls les manquants passés à apt) ; réexécution (aucun `apt-get install`, aucune réécriture de lien, `module_check` à 0) ; `~/.local/bin/fd` occupé par un fichier ordinaire (laissé intact, averti, `module_check` à 1) ; fragment retiré → `module_check` à 1 ; `config/shell/commonrc` inchangé.
Le contenu du fragment est vérifié par un chargement réel dans `sh`, `bash` et le zsh du système, comme les cas « fragments » de `tests/test-shell.sh` : `FZF_DEFAULT_COMMAND` doit être défini et mentionner `fd`.

## Risks / Trade-offs

- [Un `~/.local/bin/bat` laissé intact bloque `module_check` à « à faire » indéfiniment] → c'est voulu et visible : le message nomme le fichier et l'action à faire (le retirer). Écraser silencieusement serait pire.
- [`FZF_DEFAULT_OPTS` défini dans le fragment écrase un réglage personnel posé ailleurs] → le fragment est chargé en dernier, donc il gagne. C'est le prix de la convention ; un réglage personnel a sa place dans `~/.commonrc.d/` sous un nom qui passe après (`zz-perso.sh`), ce que l'ordre lexicographique garantit.
- [`fd --hidden` explore des dossiers volumineux (`node_modules`, `.venv`) et ralentit `fzf`] → `fd` respecte `.gitignore` par défaut, ce qui écarte ces dossiers dans un dépôt ; hors dépôt le cas reste possible, à corriger dans le fragment si l'usage le montre.
- [`lazygit` et `postgresql-client` n'ont, comme `yq`, aucun besoin consigné derrière eux] → ils restent au `ROADMAP.md` ; à retirer d'un mot si la relecture de cette proposition conclut la même chose que pour `yq`.

## Migration Plan

Aucune migration : le module n'a pas d'état antérieur. Retour arrière = `apt remove` des sept paquets, suppression des deux liens de `~/.local/bin` et du lien du fragment.
