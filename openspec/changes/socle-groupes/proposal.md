## Why

Trois modules ont désormais besoin du même geste : inscrire l'utilisateur dans un groupe système, le constater dans la base des groupes, et signaler qu'il faut rouvrir la session tant que la session en cours ne porte pas encore ce groupe. `docker` le fait déjà pour le groupe `docker` (design D3 et D5 de son change) ; `claude-desktop` (vague 2) en a besoin pour le groupe `kvm`, qu'exige Cowork. Le design de `docker` avait fixé la règle : factoriser **au troisième cas, dans un change à part** — et la ROADMAP interdit d'écrire un helper partagé dans un module.

Ce change est la « vague 0 » de la vague 2, en plus petit : il pose le helper avant que `claude-desktop` ne l'emploie. `node`, `dev-tools` et `vscode` n'en dépendent pas et peuvent avancer en parallèle.

## What Changes

- **Nouveau `lib/groups.sh`**, chargé par `setup.sh` avec les autres fichiers de `lib/` :
  - `user_in_group <groupe>` — vrai si la base des groupes du système (`getent group`) liste l'utilisateur courant, comparaison exacte du nom ; sans effet de bord, utilisable par `module_check` ;
  - `ensure_user_in_group <groupe>` — crée le groupe s'il n'existe pas (`groupadd --system`), inscrit l'utilisateur s'il n'est pas membre (`usermod -aG`), puis le constate ; échec nommé sinon ;
  - `group_relogin_step <groupe>` — si l'utilisateur est membre dans la base mais que la session courante ne porte pas le groupe, avertit et déclare l'étape manuelle « rouvrir la session » en nommant le groupe ; sans échec.
- **`modules/41-docker.sh` réécrit sur ces helpers**, sans changement de comportement : mêmes appels système, même critère « déjà fait », même étape de session. `tests/test-docker.sh` doit passer sans modification de ses assertions.

Hors périmètre :

- **L'étape de session du module `terminal`** (shell de connexion changé) : elle compare `$SHELL` à la base des comptes, pas un groupe — un autre constat, qui reste dans son module.
- **Tout autre groupe** (`kvm` compris) : c'est `claude-desktop` qui l'emploiera.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-contract` : nouvelle exigence « Appartenance de l'utilisateur à un groupe » — le socle fournit le constat, l'inscription et l'étape de réouverture de session.

## Impact

- Nouveaux `lib/groups.sh` et `tests/test-groups.sh` ; `setup.sh` charge le nouveau fichier ; `modules/41-docker.sh` allégé de ses trois fonctions privées de groupe.
- Aucune écriture système nouvelle : les commandes (`getent`, `id`, `groupadd`, `usermod`) sont celles que `docker` lance déjà.
- Docs : `CLAUDE.md` (liste des helpers du socle).
- Validation : dans la WSL (`docker` toujours « déjà fait », suite de tests verte). Pas de passage en VM propre à ce change : `claude-desktop` l'éprouvera en VM, et `docker` y repassera au même moment.
