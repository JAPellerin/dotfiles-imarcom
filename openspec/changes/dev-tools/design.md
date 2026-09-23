## Context

Voir `proposal.md`. Le socle fournit `run`, `ui_spin`, `add_cleanup`, `manual_step`, `log_*`. `config/shell/commonrc` met `~/.local/bin` en tête du `PATH` (ligne 7) — dans les shells de l'utilisateur, pas forcément dans le processus de `setup.sh` sur un poste neuf.

Relevés du 23 sept 2026, sur les scripts publiés et dans la WSL :

| Fait | Mesure |
|---|---|
| Claude Code, doc (« Advanced setup ») | méthode recommandée : `curl -fsSL https://claude.ai/install.sh \| bash` ; mise à jour automatique ; lanceur `~/.local/bin/claude` → `~/.local/share/claude/versions/<v>` |
| `install.sh` de Claude Code | télécharge le binaire, vérifie sa somme, lance `claude install` (« launcher and shell integration ») |
| twg, doc Atlassian | `curl -fsSL --retry 2 https://teamwork-graph.atlassian.com/cli/install \| bash` ; options `--skip-login`, `--version`, `--install-dir` |
| Installateur twg | **si `~/.local/bin` n'est pas dans le `PATH`**, ajoute `export PATH=…` à `~/.zshrc` (ou `~/.bashrc`/`~/.bash_profile` selon `$SHELL`) |
| `twg login` | autorisation OAuth par appareil + choix du site ; « Secrets are entered interactively and never passed as CLI flags » |
| Connexions sur disque | Claude Code : `~/.claude/.credentials.json` ; twg : `~/.config/twg/auth_oauth.conf` |
| WSL | `claude` 2.1.280 (natif), `twg` 1.3.1, tous deux connectés |

## Goals / Non-Goals

**Goals :** les deux outils posés par leurs installateurs officiels ; aucun fichier du shell modifié ; connexions signalées, jamais simulées.

**Non-Goals :** réglages de Claude Code, plugins et MCP, skills de twg, jeton Bitbucket, choix d'une version.

## Decisions

### D1. Installateurs téléchargés puis exécutés, jamais `curl | bash` dans un tube
`_dev_tools_run_installer <url> [args…]` : `curl -fsSL --retry 2 <url> -o <tmp>` (temporaire nettoyé par `add_cleanup`), puis `run bash <tmp> [args…]` sous `ui_spin`. Même script que la doc, mais un téléchargement raté échoue proprement et nommé, au lieu d'un `bash` qui exécute une page d'erreur ; la sortie va au journal.

### D2. `~/.local/bin` en tête du `PATH` avant chaque installateur
`mkdir -p ~/.local/bin` puis, s'il n'y est pas, `PATH="$HOME/.local/bin:$PATH"` exporté pour la durée du module. L'installateur de twg ne touche alors à aucun fichier (il ne le fait que si le dossier manque au `PATH`). Pour Claude Code, `claude install` règle son « intégration shell » : le passage en VM doit constater qu'aucun fichier du shell n'est modifié (tâche 2.2) ; s'il en modifiait un malgré tout, le design sera corrigé avant l'archive.
Garde-fou de test : le `HOME` isolé des tests contient des `.zshrc`/`.bashrc` dont la somme est vérifiée après le module.

### D3. Claude Code : l'installateur natif, rien d'autre
`bash install.sh` sans argument (canal `latest`, celui de la doc). Le module ne fixe ni canal ni `autoUpdates` : dans la WSL, `autoUpdates: false` est un réglage de l'utilisateur, qu'un module n'a pas à écraser.
Alternative écartée par l'utilisateur : dépôt apt `downloads.claude.ai/claude-code/apt/stable`.

### D4. twg : `--skip-login`
`bash install --skip-login` : l'installateur ne lance pas le navigateur. `twg` se met à jour lui-même (`twg update`, politique de version minimale côté serveur) : le module ne s'en occupe pas.

### D5. Connexions : constat sur disque, étape manuelle
Après installation : si `~/.config/twg/auth_oauth.conf` est absent → `manual_step "Connecter twg à Atlassian : lancer « twg login » (navigateur, choix du site)."` ; si `~/.claude/.credentials.json` est absent → `manual_step "Connecter Claude Code : lancer « claude » et suivre la connexion dans le navigateur."`. Fichiers lus pour leur présence seulement, jamais leur contenu. Hors de `module_check` : une connexion est une action de l'utilisateur, pas un état que le module produit.
Risque : ces chemins sont des détails d'implémentation des outils. S'ils changent, l'étape s'affichera à tort — sans échec ni faux « fait ».

### D6. `module_check`
`[[ -x ~/.local/bin/claude && -x ~/.local/bin/twg ]]` (`-x` suit le lien de `claude`, donc un lien cassé compte comme absent). Pas de `--version` : lancer deux binaires à chaque affichage du menu n'apporte rien de plus que `-x`.

### D7. Dépendances
`MODULE_DEPS="base shell"` : `curl` vient de `base` ; sans `shell`, `~/.local/bin` n'est pas dans le `PATH` des shells de l'utilisateur et `claude`/`twg` ne seraient pas trouvés (même raison que `cli-tools` D7). **Pas de dépendance à `node`.**

### D8. Tests
`tests/test-dev-tools.sh` (nouveau) : `HOME` isolé avec `.zshrc`/`.bashrc` témoins ; `curl` doublé (copie un faux installateur local vers `-o`, ou échoue pour une URL marquée) ; faux installateurs qui créent `~/.local/bin/claude` ou `twg`, journalisent leurs arguments et, **comme le vrai twg**, ajoutent une ligne à `~/.zshrc` si `~/.local/bin` manque au `PATH`. Cas : première installation (deux installateurs, `--skip-login` passé à twg, fichiers du shell intacts) ; réexécution → aucun téléchargement ; un seul outil manquant → un seul installateur ; téléchargement en échec → échec nommant l'URL ; connexions absentes → deux étapes manuelles ; présentes → aucune ; `module_check` sur chaque outil.

## Risks / Trade-offs

- [`curl | bash` d'éditeurs tiers] → méthode officielle des deux éditeurs ; l'installateur de Claude Code vérifie la somme du binaire ; les deux sont téléchargés en HTTPS depuis leur domaine.
- [`claude install` modifie un fichier du shell malgré D2] → constaté ou infirmé en VM (tâche 2.2) avant l'archive.
- [Mise à jour automatique de Claude Code] → comportement de la doc, choisi par l'utilisateur ; désactivable dans ses réglages.

## Migration Plan

Aucune : la WSL a déjà les deux outils. Retour arrière (docs) : `rm -f ~/.local/bin/claude && rm -rf ~/.local/share/claude` ; `rm -f ~/.local/bin/twg`.
