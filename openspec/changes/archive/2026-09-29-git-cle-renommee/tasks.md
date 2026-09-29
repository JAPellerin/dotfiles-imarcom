## 1. Renommage

- [x] 1.1 `modules/30-git.sh` : `GIT_SSH_KEY_REF` et `GIT_SSH_PUB_REF` sur `op://Private/Git SSH Key/…` (D1) ; `tests/test-git.sh` : doublure `op` sur les nouvelles références (D2) ; `CLAUDE.md` : exemple `Git SSH Key` ; vérifier `git grep 'GitHub SSH Key' -- ':!openspec/changes/archive'` vide hors de ce change, `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre
- [x] 1.2 Vérification réelle, dans la WSL (session 1Password ouverte) : `op read 'op://Private/Git SSH Key/public key' | ssh-keygen -lf -` → empreinte `SHA256:ukjG…` ; `openspec validate git-cle-renommee --strict` vert — **fait le 29 sept 2026** : `SHA256:ukjGM2KUtaan0Cmvg4DoJg9LaPv4J5btazczaOoihMs` (ED25519), la clé servie par l'agent en VM et acceptée par Bitbucket
