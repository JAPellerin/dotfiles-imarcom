## Context

Voir `proposal.md`. Le code à factoriser existe : `_docker_user_in_group`, `_docker_session_has_group`, `_docker_ensure_group` et `_docker_check_session` dans `modules/41-docker.sh`, validés en WSL et en VM le 23 sept 2026 (archive `2026-09-23-docker`, D3 et D5), avec `tests/test-docker.sh` qui double `getent`, `id` et `run_sudo`. Mesuré dans la VM Ubuntu 26.04 : le groupe `kvm` existe d'origine (`kvm:x:991:`), sans membre.

## Goals / Non-Goals

**Goals :** un seul endroit pour « membre d'un groupe », sans changer le comportement de `docker` ; un helper prêt pour `kvm`.

**Non-Goals :** l'étape de session de `terminal` (autre constat) ; un helper générique de « session à rouvrir » sans groupe.

## Decisions

### D1. Nouveau fichier `lib/groups.sh`
Un fichier par thème, comme `lib/fonts.sh` (vague 0) : `lib/module.sh` porte le contrat, `lib/files.sh` les fichiers, et un groupe système n'est ni l'un ni l'autre. Chargé par `setup.sh` à la suite des autres `lib/*.sh`. Dépend de `lib/core.sh` (`run_sudo`, `log_*`) et de `lib/module.sh` (`manual_step`).
Alternative rejetée : l'ajouter à `lib/module.sh` — il deviendrait le fourre-tout du socle.

### D2. Trois fonctions, reprises de `docker` telles quelles
- `user_in_group <groupe>` : `getent group <g> | cut -d: -f4 | tr ',' '\n' | grep -xF -- "$user" >/dev/null` — comparaison exacte ; `>/dev/null` et **jamais `grep -q`** en fin de tube (SIGPIPE sous `pipefail`, constaté sur `font_installed`). Utilisateur : `${USER:-$(id -un)}`.
- `ensure_user_in_group <groupe>` : `groupadd --system` si `getent group` échoue ; `usermod -aG` si `user_in_group` est faux ; re-vérification et échec nommé si l'inscription ne se constate pas.
- `group_relogin_step <groupe>` : rien si l'utilisateur n'est pas membre dans la base, rien si `id -nG` porte le groupe ; sinon `log_warn "La session courante ne porte pas encore le groupe <g> : il faut la rouvrir."` (le fragment « ne porte pas encore le groupe docker » est celui que vérifie `tests/test-docker.sh`) et `manual_step "Fermer puis rouvrir la session : l'appartenance au groupe <g> n'est prise en compte qu'à l'ouverture d'une session."` — le texte nomme le groupe, pour que deux modules (docker, kvm) donnent deux lignes lisibles au résumé.
Le message propre à `docker` (« d'ici là, docker demande sudo ») disparaît au profit du texte commun : l'information utile — rouvrir la session, et pour quel groupe — est conservée.

### D3. `docker` réécrit sans changement observable
`module_check` appelle `user_in_group docker` ; `module_configure` appelle `ensure_user_in_group docker`, puis le service (inchangé), puis `group_relogin_step docker`. Les constantes `DOCKER_GROUP`, `DOCKER_USER` et `DOCKER_RELOGIN_MANUAL` sont retirées. Critère de non-régression : `tests/test-docker.sh` passe **sans toucher à ses assertions** — seules les doublures pourraient devoir suivre si le helper appelait une commande différente, ce que D2 évite.

### D4. Tests
`tests/test-groups.sh` (nouveau) : doublures `getent`, `id` (fichiers), `run_sudo` (simule `groupadd` et `usermod`). Cas : membre → vrai ; nom proche (`uu` pour `u`) → faux ; membre en fin de liste → vrai ; groupe absent → faux sans erreur ; inscription (groupe présent, absent) ; déjà membre → aucun `usermod` ; inscription qui ne se constate pas → échec nommé ; session sans le groupe → étape déclarée nommant le groupe ; session à jour → rien ; non membre → rien.

## Risks / Trade-offs

- [Le texte de l'étape manuelle de `docker` change] → assumé : même sens, désormais commun ; `tests/test-docker.sh` ne vérifie que « rouvrir la session ».
- [Un quatrième usage aux besoins différents] → la signature reste minimale ; un besoin nouveau se traitera par un change du socle, comme celui-ci.

## Migration Plan

Aucune migration : aucun état n'est stocké. Retour arrière = revenir au commit précédent de `modules/41-docker.sh`.
