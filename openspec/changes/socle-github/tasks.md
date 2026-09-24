## 1. Helper

- [x] 1.1 `lib/github.sh` : `github_release_asset_url` selon D1 à D4, en-tête dans le style des autres `lib/*.sh` ; chargé par `setup.sh` après `lib/apt.sh` ; vérifier `shellcheck lib/github.sh setup.sh` propre et, en réel, `github_release_asset_url obsidianmd/obsidian-releases '_amd64\.deb$'` → l'URL du `.deb` de v1.13.7 (ou plus récent), pas l'`.apk` de v1.13.8
- [x] 1.2 `tests/test-github.sh` : les cas de D5 ; vérifier `bash tests/test-github.sh` vert et qu'une mutation (retirer le filtre `prerelease`, ou prendre `/releases/latest`) le fait échouer

## 2. Vérification d'ensemble et documentation

- [x] 2.1 `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre ; `CLAUDE.md` : le helper dans la liste des helpers du socle ; `ROADMAP.md` : vague 3 = `socle-github` d'abord, puis `obsidian`, `rocketchat`, `thunderbird`, `spotify` et `vpn` — ce dernier **installation seule**, configuration du profil reportée (profil et méthode de connexion à retrouver auprès de l'équipe TI, 23 sept 2026) ; `openspec validate socle-github --strict` vert

## 3. Corrections après revue (24 sept 2026)

- [x] 3.1 `lib/github.sh` : réponse gardée dans une variable, plus de fichier temporaire (`add_cleanup` se perdait dans le `$(…)` de l'appelant, le fichier restait dans `$TMPDIR`) ; cause rapportée par `curl` et motif dans les messages d'échec ; motif vérifié avant l'appel réseau ; « expression régulière étendue » corrigé en « expression régulière de `jq` » (Oniguruma) dans le code, la proposition et le design
- [x] 3.2 `tests/test-github.sh` : `TMPDIR` vide après les appels, motif et cause de `curl` dans les messages, motif invalide ; vérifié que l'ancien helper échoue à ces cas (5 échecs)
