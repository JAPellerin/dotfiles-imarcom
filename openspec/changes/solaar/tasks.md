## 1. Module `solaar`

- [x] 1.1 `modules/71-solaar.sh` (D1 à D3) — en-tête avec liens officiels (https://pwr-solaar.github.io/Solaar/) ; vérifier `shellcheck` propre et `./setup.sh --list` → `solaar` dans `[bureau]`, « non disponible ici » dans la WSL — **fait le 30 sept 2026** : `[bureau] solaar … non disponible ici` dans la WSL, `shellcheck` propre
- [x] 1.2 `tests/test-solaar.sh` : cas de D4 ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre — **fait le 30 sept 2026** : 17 assertions (métadonnées acceptées par `module_meta`, première installation avec `DEBIAN_FRONTEND=noninteractive` constaté par le faux `apt-get`, relance sans aucun `apt-get`, paquet retiré → à faire) ; `run-all.sh` vert

## 2. Validation en VM et documentation

- [ ] 2.1 VM : `git pull` puis `./setup.sh solaar` → `dpkg -s solaar` ; `grep USE_PLUGDEV_GROUP /etc/default/solaar` → `"false"` ; réouverture de session → processus `solaar` lancé et icône dans la barre du haut ; relance → « déjà fait » ; consigner ici (détection des appareils : sur le laptop)
- [ ] 2.2 `ROADMAP.md` : ligne 71 `solaar` au tableau (et mention dans la vague 6) ; `openspec validate solaar --strict` vert — **en cours, 30 sept 2026** : ligne 71 ajoutée au tableau (`c8532fb`) ; la mention dans la vague 6 est écrite par la tâche 3.3 d'`orca` (paragraphe commun aux deux modules, même session que `orca`)
