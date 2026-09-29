## 0. Relevés

- [ ] 0.1 VM (poste où `projets` est passé) : lancer Firefox une fois puis le fermer → emplacement du profil (`ls -d ~/.mozilla/firefox/*/ ~/.config/mozilla/firefox/*/`) ; `mkdir -p ~/.pki/nssdb && certutil -N -d sql:$HOME/.pki/nssdb --empty-password`, ajouter l'autorité (`certutil -A … -i "$(mkcert -CAROOT)/rootCA.pem"`), lancer Brave → page https locale servie par un certificat `mkcert` (`mkcert localhost` + `python3 -m http.server` en https, ou le proxy du projet) sans avertissement ; même essai dans Firefox après ajout à son profil ; relever la commande la plus simple qui liste les empreintes d'une base (`certutil -L`) et la présence d'`openssl` ; consigner dans `design.md` (Context, D1 à D3)

## 1. Module

- [ ] 1.1 `modules/80-projets.sh` : base partagée (D1), bases visées (D2), ajout et reconnaissance par empreinte (D3), `module_check` (D4) ; vérifier `shellcheck` propre
- [ ] 1.2 `tests/test-projets.sh` : cas de D5 ; vérifier `bash tests/run-all.sh` vert

## 2. Validation

- [ ] 2.1 VM : `./setup.sh projets` → base partagée créée, autorité dans la base partagée et le profil Firefox ; Brave et Firefox ouvrent la page https locale sans avertissement ; relance → « déjà fait » ; nouveau profil Firefox (`firefox -CreateProfile essai`) → `--list` : « à faire », relance → ajouté ; consigner ici ; `openspec validate mkcert-navigateurs --strict` vert
