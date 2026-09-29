## Context

Voir `proposal.md`. Code actuel (`modules/80-projets.sh`) : `_projets_ca_ok` = `rootCA.pem` sous `mkcert -CAROOT` **et** `mkcert_development_CA_*.crt` dans le magasin du système ; `_projets_mkcert` lance `mkcert -install` si ce constat échoue — donc plus jamais une fois le magasin du système rempli. Relevés en VM (29 sept 2026) : `libnss3-tools` installé par le module (fournit `certutil`) ; Brave lancé mais `~/.pki/nssdb` absent ; Firefox 157, jamais lancé, aucun des dossiers `~/.mozilla/firefox`, `~/.config/mozilla/firefox`. `mkcert` 1.4.4 cherche `~/.pki/nssdb`, `~/.mozilla/firefox/*` et le chemin du snap seulement.

## Goals / Non-Goals

**Goals :** l'autorité reconnue par Brave et Firefox, même installés ou lancés après le module ; constat hors ligne, sans `sudo`.

**Non-Goals :** gérer les certificats par stratégie d'entreprise ; retirer l'autorité ; navigateurs en snap ou flatpak.

## Decisions

### D1. Base partagée créée d'avance
`~/.pki/nssdb` absente → `mkdir -p` (0700) puis `certutil -N -d sql:$HOME/.pki/nssdb --empty-password` (base vide, sans mot de passe — comme Chromium la créerait). Chromium, Brave et Chrome l'ouvrent au démarrage si elle existe (à confirmer, tâche 0.1).

### D2. Bases visées
Constante `PROJETS_NSS_GLOBS` : `$HOME/.pki/nssdb` et les profils Firefox `$HOME/.mozilla/firefox/*/` et `$HOME/.config/mozilla/firefox/*/` — un profil est une base s'il contient `cert9.db`. Emplacement de Firefox 157 relevé en tâche 0.1 ; la liste garde les deux formes (un profil importé d'une autre version peut vivre à l'ancien endroit).

### D3. Ajout par `certutil`, reconnaissance par empreinte
Autorité : `$(mkcert -CAROOT)/rootCA.pem`. Présence dans une base : l'empreinte SHA-256 de `rootCA.pem` (`openssl x509 -noout -fingerprint -sha256`) figure parmi celles des certificats de la base — reconnaît aussi un ajout fait par `mkcert -install` sous son propre surnom. Ajout : `certutil -A -d sql:<base> -t C,, -n "mkcert development CA" -i rootCA.pem`. Surnom volontairement différent de celui de mkcert (`mkcert development CA <numéro de série en décimal>`, source `cert.go` de la 1.4.4, contre-vérification du 29 sept 2026) : le numéro de série est un entier de 128 bits, hors de portée de l'arithmétique du shell, et l'empreinte suffit à reconnaître l'autorité quel que soit son surnom. Écarté : relancer `mkcert -install` (ne voit pas un profil hors de ses chemins, et ne dit pas ce qu'il a fait).
Lecture des empreintes d'une base : `certutil -L -d sql:<base>` pour les surnoms, puis `certutil -L -a -n <surnom>` → `openssl` ; méthode exacte arrêtée à la tâche 0.1 (la plus simple qui marche sur `certutil` d'Ubuntu 26.04).

### D4. `module_check`
Ajoute : `~/.pki/nssdb/cert9.db` existe ; pour chaque base présente, l'autorité y figure (D3, lecture seule). Coût : quelques `certutil` par affichage du menu, acceptable (une ou deux bases).

### D5. Tests
Doublures `certutil` et `openssl` (bases simulées par des dossiers et un fichier d'empreintes), `mkcert -CAROOT` du test. Cas : aucune base → base partagée créée et autorité ajoutée ; profil Firefox (chacun des deux emplacements) sans autorité → ajouté, `module_check` 1 avant, 0 après ; autorité déjà présente sous un autre surnom → rien ajouté ; autres certificats de la base intacts ; relance → rien refait.

## Open Questions

- **Firefox par stratégie d'entreprise plutôt que par profil** (contre-vérification, 29 sept 2026) : la stratégie `Certificates.Install` (fichier `config/navigateur/firefox-policies.json`, déjà posé par `navigateur`) installe une autorité dans tout profil au démarrage, y compris un profil créé plus tard — plus de parcours des profils, plus de `certutil` sur une base peut-être ouverte, plus de condition de `module_check` par profil. Coût : un couplage entre modules (`projets` copierait `rootCA.pem` sous un nom fixe dans `/usr/lib/mozilla/certificates/` et la stratégie de `navigateur` le nommerait), et Brave/Chromium n'ont pas d'équivalent sous Linux, donc D1 reste. À trancher par l'utilisateur avant la tâche 1.1 ; si retenu : D2 se réduit à `~/.pki/nssdb`, et `navigateur` gagne la ligne de stratégie.

## Risks / Trade-offs

- [Navigateur ouvert pendant l'ajout] → `certutil` sur une base SQLite ouverte : sûr (format `sql:` prévu pour l'accès partagé) ; le navigateur voit l'ajout à son prochain démarrage.
- [Brave n'utiliserait pas `~/.pki/nssdb`] → relevé en tâche 0.1 ; sinon, la base de Brave est ajoutée à D2.
- [Empreinte par `openssl`] → `openssl` est dans l'installation de base d'Ubuntu ; vérifié en tâche 0.1.
