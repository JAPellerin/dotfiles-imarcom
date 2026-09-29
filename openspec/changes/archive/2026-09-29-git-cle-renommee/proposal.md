## Why

L'utilisateur a renommé l'élément 1Password de sa clé SSH de travail de « GitHub SSH Key » en **« Git SSH Key »** (29 sept 2026) : la même clé sert désormais GitHub **et** Bitbucket (validation de `projets` en VM, clé publique ajoutée à Bitbucket). Le module `git` lit encore `op://Private/GitHub SSH Key/…` : rien ne casse tant que l'agent de l'application sert la clé ou qu'une clé existe déjà sur disque, mais sur un poste sans l'application et sans `~/.ssh/id_ed25519`, le module échouerait à la lire.

## What Changes

- `modules/30-git.sh` : références `op://Private/Git SSH Key/private key?ssh-format=openssh` et `op://Private/Git SSH Key/public key`.
- Spec `module-git`, exigence « Clé SSH selon l'environnement » : nouveau nom de l'élément, clé décrite comme « clé SSH git » (GitHub et Bitbucket) plutôt que « clé SSH GitHub ».
- `tests/test-git.sh` : doublure `op` sur les nouvelles références.
- `CLAUDE.md` : l'exemple de nom d'élément devient `Git SSH Key`.

Hors périmètre : `known_hosts` de Bitbucket (module `projets`) ; tout changement de comportement du module.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-git` : nom de l'élément 1Password de la clé SSH.

## Impact

- Modifiés : `modules/30-git.sh`, `tests/test-git.sh`, `CLAUDE.md`.
- 1Password : l'élément `op://Private/Git SSH Key` (déjà renommé par l'utilisateur) ; l'ancien nom n'existe plus.
- Aucune écriture système, aucun réseau nouveau. Les postes existants ne changent pas (clé servie par l'agent, ou fichier existant laissé intact).
