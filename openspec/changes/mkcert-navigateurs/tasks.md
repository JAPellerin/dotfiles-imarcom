## 0. Relevés

- [ ] 0.1 VM (poste où `projets` est passé) : lancer Firefox une fois puis le fermer → emplacement du profil (`ls -d ~/.mozilla/firefox/*/ ~/.config/mozilla/firefox/*/`) ; `mkdir -p ~/.pki/nssdb && certutil -N -d sql:$HOME/.pki/nssdb --empty-password`, ajouter l'autorité (`certutil -A … -i "$(mkcert -CAROOT)/rootCA.pem"`), lancer Brave → page https locale servie par un certificat `mkcert` (`mkcert localhost` + `python3 -m http.server` en https, ou le proxy du projet) sans avertissement ; même essai dans Firefox après ajout à son profil ; relever la commande la plus simple qui liste les empreintes d'une base (`certutil -L`) et la présence d'`openssl` ; consigner dans `design.md` (Context, D1 à D3)

## 1. Module

- [x] 1.1 `modules/80-projets.sh` : base partagée (D1), bases visées (D2), ajout et reconnaissance par empreinte (D3), `module_check` (D4) ; vérifier `shellcheck` propre
- [x] 1.2 `tests/test-projets.sh` : cas de D5 ; vérifier `bash tests/run-all.sh` vert — **fait le 29 sept 2026** : `certutil` et `openssl` réels (D5), 17 assertions (base partagée créée en 0700 avec l'autorité ; profils Firefox aux deux emplacements complétés ; autre certificat gardé ; autorité déjà posée sous le surnom de `mkcert -install` reconnue par empreinte, rien ajouté ; relance sans ajout ; base partagée retirée → à faire puis recréée) — 10 échouent sans le correctif ; méthode de lecture de D3 confirmée sur de vraies bases (en-tête de 4 lignes, surnom puis attributs de confiance)

## 2. Validation

- [ ] 2.1 VM : `./setup.sh projets` → base partagée créée, autorité dans la base partagée et le profil Firefox ; Brave et Firefox ouvrent la page https locale sans avertissement ; relance → « déjà fait » ; nouveau profil Firefox (`firefox -CreateProfile essai`) → `--list` : « à faire », relance → ajouté ; consigner ici ; `openspec validate mkcert-navigateurs --strict` vert
