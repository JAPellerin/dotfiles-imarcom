## Why

Sur un poste neuf, la première chose qui a besoin d'un navigateur est `gh auth login` (module `git`) : la connexion à GitHub se fait dans le navigateur, avec les identifiants rangés dans 1Password. Le module `navigateur` vient donc **avant** `git` (préfixe `25`, décision du 18 sept 2026) et installe, en plus du ou des navigateurs choisis, l'**extension 1Password** — pré-installée par stratégie d'entreprise, sans passer par le magasin d'extensions à la main. C'est aussi le premier module à choix interne (contrat de module : question posée dans `module_install`, toujours « à faire »), le premier module `MODULE_NEEDS_GUI=1` et le premier à écrire des fichiers système hors `apt` (stratégies de navigateur, épinglage apt).

## What Changes

- **Module `navigateur`** (`modules/25-navigateur.sh`, groupe `apps`, dépend de `base` et `1password`, `MODULE_NEEDS_GUI=1`) :
  - **question au début de `module_install`** : sélection multiple parmi **Brave**, **Firefox**, **Google Chrome** (navigateurs déjà installés précochés) ; si Firefox est choisi, **langue de Firefox** (comme Ubuntu, français ou anglais — Brave et Chrome suivent la langue du système, sans réglage possible sur Linux) ; **navigateur par défaut** demandé quand le défaut courant n'est pas l'un des navigateurs choisis (un seul choisi → posé d'office) ;
  - installation **depuis le dépôt apt officiel de chaque éditeur**, via le helper deb822 du socle : Brave (`brave-browser-apt-release.s3.brave.com`, paquet `brave-browser`), Mozilla (`packages.mozilla.org/apt`, suite `mozilla`, paquet `firefox`, avec l'**épinglage** `Pin-Priority: 1000` demandé par Mozilla pour supplanter le paquet de transition d'Ubuntu qui installe le snap), Google (`dl.google.com/linux/chrome/deb/`, paquet `google-chrome-stable`, avec `repo_add_once="false"` dans `/etc/default/google-chrome` pour que le paquet ne crée pas son propre `.list` en double) ;
  - Firefox : `.deb` de Mozilla à la place du **snap**, qui est retiré une fois le `.deb` en place (uniquement si Firefox est choisi) ; en français (choisi ou détecté depuis la langue d'Ubuntu), paquet `firefox-l10n-fr` et préférence `intl.locale.requested=fr` (modifiable par l'utilisateur) ; en anglais, aucun paquet de langue (retiré s'il était là) ;
  - **extension 1Password** déployée par stratégie (`installation_mode: normal_installed` : installée et activée automatiquement, l'utilisateur peut la désactiver) pour chaque navigateur pris en charge présent sur la machine : `/etc/brave/policies/managed/`, `/etc/opt/chrome/policies/managed/`, `/etc/firefox/policies/policies.json` ; fichiers versionnés dans `config/navigateur/` ;
  - **Brave Sync** (étape guidée, décision du 21 sept 2026) : rejoindre une chaîne de synchronisation ne passe que par l'interface de Brave, et le code de 25 mots expire (le 25ᵉ mot encode la date). Quand Brave est installé et qu'aucune chaîne n'est rejointe, le module lit les 24 mots de la graine dans 1Password, **calcule le 25ᵉ mot du jour** (liste BIP39 versionnée), place la phrase dans le presse-papiers, ouvre Brave sur la page de synchronisation avec la consigne, et attend que la chaîne soit rejointe ; l'utilisateur peut passer (étape manuelle consignée dans le résumé) ;
  - **navigateur par défaut** via `xdg-settings` ;
  - `module_check` toujours « à faire » (choix interne) ; chaque exécution n'installe que ce qui manque.
- **Socle** : `apt_install_pinned` (`lib/apt.sh`, installe ou remplace par la version choisie par l'épinglage apt, même si un paquet du même nom est présent), `apt_remove` (`lib/apt.sh`, retire les paquets présents) et `install_system_file` (`lib/files.sh`, copie d'un fichier vers un chemin système avec `sudo`, idempotente par comparaison de contenu), avec leurs tests.

Hors périmètre : autres navigateurs (Chromium, Edge, Vivaldi…), langue d'interface de Brave et Chrome (suivent Ubuntu ; forcer une autre langue demanderait un lanceur `.desktop` surchargé, refusé le 21 sept 2026), synchronisation de Firefox et de Chrome, choix des données synchronisées par Brave (fait dans l'interface une fois la chaîne rejointe), réglages internes (page d'accueil, moteur de recherche), retrait du snap `firefox` quand Firefox n'est pas choisi (à voir dans `gnome` ou `base`), activation des réglages de l'app 1Password (signés, hors de portée du script — voir `module-1password`), vérification de l'état « activée » de l'extension (préférences protégées par HMAC dans le profil du navigateur, non modifiables ; la stratégie l'installe activée).

## Capabilities

### New Capabilities
- `module-navigateur` : le module `navigateur` — choix des navigateurs, installation depuis les dépôts officiels, remplacement du snap Firefox et langue de Firefox, extension 1Password par stratégie, Brave Sync guidé, navigateur par défaut.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/25-navigateur.sh`, `config/navigateur/` (stratégies JSON, épinglage Mozilla, `/etc/default/google-chrome`, liste BIP39 anglaise), `tests/test-navigateur.sh` ; `lib/apt.sh` et `lib/files.sh` étendus (+ cas dans `tests/test-apt.sh`, `tests/test-files.sh`).
- Secret lu : `op://Imarcom/Brave Sync Code/notesPlain` (note sécurisée, coffre `Imarcom` — exception à la convention `Private`, assouplie le 21 sept 2026 ; graine de 24 mots) — jamais journalisé ; passe par le presse-papiers (`wl-clipboard`), vidé une fois la chaîne rejointe.
- Dépôts apt tiers : Brave (clé binaire `.gpg`), Mozilla (clé armurée `.asc` + `/etc/apt/preferences.d/mozilla`), Google (clé armurée `.asc`, `amd64`).
- Fichiers système hors apt : `/etc/brave/policies/managed/1password.json`, `/etc/opt/chrome/policies/managed/1password.json`, `/etc/firefox/policies/policies.json`, `/etc/default/google-chrome`.
- Snap : `snap remove firefox` quand Firefox est choisi (données du snap dans `~/snap/firefox` laissées en place).
- Paquet supplémentaire : `wl-clipboard` (presse-papiers Wayland) pour l'étape Brave Sync.
- Dans la WSL : module « non disponible ici » (`has_gui` faux) ; seuls les tests hors ligne tournent. Validation réelle en VM (snapshot « vierge »).
- Docs : `ROADMAP.md` (`navigateur` fait), `CLAUDE.md` (stratégies de navigateur comme mécanisme de pré-installation d'extensions).
