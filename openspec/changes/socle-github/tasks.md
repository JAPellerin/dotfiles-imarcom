## 1. Helper

- [x] 1.1 `lib/github.sh` : `github_release_asset_url` selon D1 à D4, en-tête dans le style des autres `lib/*.sh` ; chargé par `setup.sh` après `lib/apt.sh` ; vérifier `shellcheck lib/github.sh setup.sh` propre et, en réel, `github_release_asset_url obsidianmd/obsidian-releases '_amd64\.deb$'` → l'URL du `.deb` de v1.13.7 (ou plus récent), pas l'`.apk` de v1.13.8
- [x] 1.2 `tests/test-github.sh` : les cas de D5 ; vérifier `bash tests/test-github.sh` vert et qu'une mutation (retirer le filtre `prerelease`, ou prendre `/releases/latest`) le fait échouer

## 2. Vérification d'ensemble et documentation

- [x] 2.1 `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre ; `CLAUDE.md` : le helper dans la liste des helpers du socle ; `ROADMAP.md` : vague 3 = `socle-github` d'abord, puis `obsidian`, `rocketchat`, `thunderbird`, `spotify` et `vpn` — ce dernier **installation seule**, configuration du profil reportée (profil et méthode de connexion à retrouver auprès de l'équipe TI, 23 sept 2026) ; `openspec validate socle-github --strict` vert
