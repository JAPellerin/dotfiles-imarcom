## Context

Voir `proposal.md`. Le socle fournit `run`, `ui_spin`, `add_cleanup`, `manual_step`, `log_*`, `install_system_file`. Pas de helper d'archive : un seul module de la vague en a besoin (règle de la ROADMAP : un helper s'écrit avant la vague quand **plusieurs** modules le partagent).

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Paquet `thunderbird` d'Ubuntu 26.04 (VM) | `2:1snap1-0ubuntu5` : transition vers le snap ; non installé, aucun snap Thunderbird présent |
| Dépôt apt de Mozilla | aucun paquet `thunderbird` |
| `download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=fr` | 302 → `…/thunderbird/releases/156.0.1/linux-x86_64/fr/thunderbird-156.0.1.tar.xz` |
| Doc de Mozilla « Install Thunderbird on Linux » | deux méthodes, système (`/opt/thunderbird`, lien `/usr/local/bin/thunderbird`, `.desktop` dans `/usr/local/share/applications`, **mise à jour = réinstaller**) ou dossier personnel ; `.desktop` publié sur `github.com/mozilla/sumo-kb/…/installing-thunderbird-linux/thunderbird.desktop` (`Exec=thunderbird %u`, `Icon=/opt/thunderbird/chrome/icons/default/default128.png`, `MimeType=x-scheme-handler/mailto;…`, actions `Compose` et `Contacts`) |
| Limite du relevé | le détail de la méthode « dossier personnel » n'a pas pu être lu (page rendue par JavaScript) : les emplacements de D2 sont une décision de ce design, à comparer à la page (tâche 2.1) — fait : ligne suivante |
| Méthode « dossier personnel » (lue le 24 sept 2026 dans la copie de la Wayback Machine du 7 mai 2026, article mis à jour le 1er sept 2025) | archive extraite dans `$HOME/thunderbird` « ou ailleurs dans votre compte » ; lanceur `~/.local/share/applications/thunderbird.desktop`, `Exec` et `Icon` réécrits vers le dossier d'installation (`sed`) ; **aucun lien de commande** ; la commande `wget` de la page dépose le lanceur dans `$HOME/.local/bin/thunderbird`, en contradiction avec le `sed` qui suit (coquille de la page) → **D2 et D3 conformes** : `~/.local/share/thunderbird` est un emplacement du compte, le lanceur est au même endroit avec les mêmes réécritures ; le lien `~/.local/bin/thunderbird` est un ajout |

Relevés du 24 sept 2026 (test en VM, puis demande de l'utilisateur : langue d'Ubuntu, dictionnaires anglais (Canada) et français) :

| Fait | Mesure |
|---|---|
| VM | Thunderbird 156.0.1 installé en `fr`, s'ouvre, recherche de mise à jour fonctionnelle ; profil dans `~/.config/thunderbird` (pas `~/.thunderbird`) ; Ubuntu en `LANG=en_US.UTF-8`, `LANGUAGE` vide |
| Langues publiées (`product-details.mozilla.org/1.0/thunderbird_primary_builds.json`) | af ar ast be bg br ca cak cs cy da de dsb el en-CA en-GB en-US es-AR es-ES es-MX et eu fi fr fy-NL ga-IE gd gl he hr hsb hu hy-AM id is it ja ka kab kk ko lt lv mk ms nb-NO nl nn-NO pa-IN pl pt-BR pt-PT rm ro ru sk sl sq sr sv-SE th tr uk uz vi zh-CN zh-TW — **pas de `fr-CA`** |
| Langue d'une installation | `unzip -p omni.ja res/multilocale.txt` → `fr,en-US` (langue de la version en premier) ; `unzip` est dans les paquets de `base` |
| Dictionnaires | la version `fr` contient `dictionaries/fr.{aff,dic}` ; aucun signe que la version de Mozilla lise `/usr/share/hunspell` (VM : seul `hunspell-en-us` y est) |
| Modules de dictionnaire (addons.thunderbird.net) | `en-CA@dictionaries.addons.mozilla.org` (« Canadian English Dictionary », 3.1.3) ; `fr-dicollecte@dictionaries.addons.mozilla.org` (« Dictionnaire français », 6.3.1, ≈ 109 000 utilisateurs) ; adresses stables par *slug* vérifiées (200, `application/x-xpinstall`) : `…/thunderbird/downloads/latest/canadian-english-dictionary/latest.xpi`, `…/thunderbird/downloads/latest/dictionnaire-fran%C3%A7ais1/latest.xpi` ; par GUID : 404 |
| Emplacement de la stratégie | non confirmé par le README de `thunderbird/policy-templates` : `/etc/thunderbird/policies/policies.json` (comme `/etc/firefox/policies/` pour Firefox) ; **constaté en VM le 24 sept 2026 : lu** — au lancement suivant, les deux dictionnaires sont installés dans le profil et actifs (`extensions.json`) |

## Goals / Non-Goals

**Goals :** archive officielle dans la langue d'Ubuntu, installation sans `sudo`, mise à jour intégrée fonctionnelle, lanceur avec icône, dictionnaires anglais (Canada) et français, rien de retéléchargé sur une relance.

**Non-Goals :** comptes, client de courriel par défaut, snap, PPA, choix du dictionnaire par défaut à la rédaction (Thunderbird propose ceux qui sont installés).

## Decisions

### D1. Archive par l'adresse de téléchargement de Mozilla
`https://download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=@LANG@` (constante `THUNDERBIRD_URL`, `@LANG@` remplacé par la langue de D6) : Mozilla y redirige vers la dernière version publiée. Téléchargée par `curl -fsSL` dans un temporaire (`add_cleanup`), extraite par `tar -xJf` dans un dossier temporaire **créé dans `~/.local/share`** (`mktemp -d ~/.local/share/.thunderbird.XXXXXX`, nettoyé par `add_cleanup`), puis **renommée** à son emplacement final seulement si l'extraction a réussi et contient `thunderbird/thunderbird` : jamais de dossier d'installation à moitié écrit. Le dossier temporaire est sur le même système de fichiers que la destination, si bien que `mv` est un renommage atomique ; extraite sous `/tmp` (souvent un `tmpfs`), l'archive serait **copiée** vers `~/.local/share`, et une coupure en cours de copie laisserait justement un dossier partiel (relevé à la contre-vérification du 23 sept 2026). Un dossier temporaire `~/.local/share/.thunderbird.XXXXXX` qu'une exécution tuée n'a pas pu nettoyer (SIGKILL, coupure de courant ; ≈ 300 Mio) est retiré au début de l'installation suivante (contre-vérification du 24 sept 2026). Langue : celle d'Ubuntu (D6, révisé le 24 sept 2026 ; d'abord `fr` en dur).

### D2. Emplacements : `~/.local/share/thunderbird`, `~/.local/bin/thunderbird`, `~/.local/share/applications/thunderbird.desktop`
Dossier d'installation dans `~/.local/share` (données d'application de l'utilisateur, XDG), appartenant à l'utilisateur : la mise à jour intégrée y écrit. Commande par lien symbolique dans `~/.local/bin`, déjà en tête du `PATH` par `commonrc`. Alternative écartée : `/opt/thunderbird` (méthode système de la doc) — la doc elle-même y prévoit une réinstallation à chaque version.

### D3. Lanceur généré depuis un gabarit versionné
`config/thunderbird/thunderbird.desktop` : copie du fichier de Mozilla, où `Exec` et `Icon` portent `@THUNDERBIRD_DIR@`. Le module remplace ce jeton par le chemin absolu d'installation et écrit le résultat dans `~/.local/share/applications/thunderbird.desktop` (fichier, pas lien : un `.desktop` n'interprète ni `~` ni `$HOME`, et `Exec` doit désigner le binaire même si `~/.local/bin` n'est pas dans le `PATH` de la session graphique). `Exec` absolu plutôt que `thunderbird` : la session graphique ne lit pas `~/.commonrc`. Dans `Exec`, le chemin est **entre guillemets** (`Exec="@THUNDERBIRD_DIR@/thunderbird" %u`) : un dossier personnel contenant une espace couperait sinon la commande ; `Icon` est une valeur simple, sans guillemets. Le commentaire d'en-tête du gabarit ne contient jamais le jeton en toutes lettres, sinon il serait remplacé aussi (contre-vérification du 24 sept 2026). `update-desktop-database ~/.local/share/applications` s'il est présent (pour les `MimeType`), sans échec s'il ne l'est pas.
Le lanceur est réécrit seulement si son contenu diffère du gabarit rendu (constat par comparaison).

### D4. `module_check` et découpage
`module_check` : `~/.local/share/thunderbird/thunderbird` exécutable **et** installation dans la langue d'Ubuntu (D6) **et** `~/.local/bin/thunderbird` lien vers lui **et** lanceur identique au gabarit rendu **et** stratégie des dictionnaires identique au dépôt (D7). `module_install` : archive (D1) seulement si le binaire manque, puis étape manuelle des comptes quand il vient d'être installé (déclarée **dans `module_install`** : le runner lance chaque fonction dans son propre sous-shell, aucune variable ne passe à `module_configure`). `module_configure` : stratégie des dictionnaires (D7), lien de commande et lanceur (D2, D3), sans réseau — c'est ce qui permet de rétablir un lanceur retiré sans retélécharger.
La version d'une installation existante n'est pas vérifiée : Thunderbird se met à jour lui-même. Sa langue l'est (D6, révisé le 24 sept 2026).

### D4b. Dépendance à `shell`
`MODULE_DEPS="base shell"` : la commande `~/.local/bin/thunderbird` (D2) n'est trouvée dans un terminal que si `~/.local/bin` est dans le `PATH`, ce que fait `~/.commonrc`, posé par `shell` — même raison que `dev-tools` D7 et `cli-tools` D7. Le lanceur n'en dépend pas (`Exec` absolu, D3). Ajouté à la contre-vérification du 23 sept 2026.

### D6. Langue d'Ubuntu (ajouté le 24 sept 2026, à la demande de l'utilisateur)
Langue d'Ubuntu lue comme gettext : premier élément de `LANGUAGE` s'il est défini et n'est pas `C`/`POSIX`, sinon `LC_ALL`, `LC_MESSAGES`, `LANG`. `ll_CC.codeset@mod` → `ll-CC` s'il fait partie des langues publiées par Mozilla (liste en constante, relevé du Context), sinon `ll`, sinon `en-US`. Ainsi `fr_CA` → `fr`, `en_CA` → `en-CA`, `en_US` → `en-US`. Constante plutôt qu'une lecture de `product-details` : `module_check` reste sans réseau.
Langue installée : premier élément de `res/multilocale.txt` dans `omni.ja` (`unzip -p`), sans réseau. `module_check` est « à faire » si elle diffère de celle d'Ubuntu ou est illisible. `module_install` télécharge alors l'archive de la bonne langue, l'extrait comme en D1, **vérifie la langue de l'archive extraite** (autre ou illisible → échec nommé, rien de remplacé : sinon chaque relance réinstallerait), puis échange : l'ancien dossier est renommé dans le dossier temporaire (même système de fichiers, retiré par `add_cleanup`), le nouveau prend sa place ; si ce second renommage échoue, l'ancien est remis. Le profil (`~/.config/thunderbird`) n'est jamais touché, et l'étape des comptes n'est pas redéclarée (ils sont dans le profil). Alternative écartée : paquets de langue (`langpack`) sur une version unique, plus de pièces pour le même résultat.

### D7. Dictionnaires par stratégie d'entreprise (ajouté le 24 sept 2026, à la demande de l'utilisateur)
`config/thunderbird/policies.json` : `ExtensionSettings`, `installation_mode: normal_installed` (installé d'office, l'utilisateur peut le désactiver) pour `en-CA@dictionaries.addons.mozilla.org` et `fr-dicollecte@dictionaries.addons.mozilla.org`, `install_url` par *slug* (relevé du Context) ; copié par `install_system_file` vers `$THUNDERBIRD_ETC/etc/thunderbird/policies/policies.json` (racine surchargeable pour les tests, comme `NAV_ETC`) dans `module_configure`. Même mécanisme que les extensions des navigateurs (décision du 21 sept 2026) ; Thunderbird installe les dictionnaires au démarrage suivant. Seule écriture système du module : sans changement, `install_system_file` n'appelle pas `sudo`.
Emplacement dans `/etc` plutôt que `<installation>/distribution/policies.json` : il survit à une réinstallation (D6) et reste hors du dossier que la mise à jour intégrée réécrit. **Constaté en VM le 24 sept 2026 : Thunderbird lit bien `/etc/thunderbird/policies/`** (dictionnaires installés et actifs au lancement suivant) ; le repli envisagé, `distribution/policies.json` dans le dossier d'installation, est inutile.
Alternative écartée : paquets `hunspell-fr`/`hunspell-en-ca` d'Ubuntu, que la version de Mozilla ne semble pas lire (Context).

### D5. Tests
`tests/test-thunderbird.sh` : `HOME` isolé ; archive `.tar.xz` fabriquée sur place (un faux `thunderbird/thunderbird` qui répond à `--version`, une icône), servie en `file://` par surcharge de `THUNDERBIRD_URL` ; fonctions appelées **par `module_call`**. Cas : première application (dossier installé, appartenant à l'utilisateur, lien de commande, lanceur avec `Exec` (chemin entre guillemets) et `Icon` absolus vers le dossier d'installation, chemin rendu seulement dans `Exec` et `Icon`, aucun `@THUNDERBIRD_DIR@` restant, étape des comptes) ; déjà installé → aucun téléchargement ; lanceur retiré → `module_check` à faire, `module_configure` le rétablit sans téléchargement ; lanceur modifié à la main → rétabli ; archive injoignable ou illisible → échec nommé, aucun dossier `~/.local/share/thunderbird` ni dossier temporaire `~/.local/share/.thunderbird.*` restant ; archive sans `thunderbird/thunderbird` → échec, aucun dossier ; dossier temporaire d'une extraction interrompue → retiré, installation réussie ; dossier personnel avec une espace → installé, `Exec` cité, `module_check` à 0 ; langue d'Ubuntu (D6) : `fr_CA` → `fr`, `en_CA` → `en-CA`, `en_US` → `en-US`, `pt_BR` → `pt-BR`, `de_DE` → `de`, `@mod` retiré, langue non publiée, `C` ou vide → `en-US`, priorité `LANGUAGE` > `LC_ALL` > `LC_MESSAGES` > `LANG`, `LANGUAGE=C` ignoré ; archives par langue (`omni.ja` porte `res/multilocale.txt`, `@LANG@` dans `THUNDERBIRD_URL`) : téléchargement dans la langue d'Ubuntu ; Ubuntu passé dans une autre langue → à faire, réinstallation, ancien dossier retiré, profil intact, aucune étape des comptes, aucun temporaire ; langue installée illisible → réinstallation ; archive dans une autre langue que celle demandée → échec nommé, installation existante conservée ; stratégie (D7) : JSON valide, deux dictionnaires `normal_installed` et leurs adresses, copiée par `run_sudo` (doublure), déjà là → aucun `sudo`, retirée ou différente → à faire puis réécrite, écriture en échec → `module_configure` échoue ; `sudo` seulement pour la stratégie ; `module_check` sur chaque condition. Avertissements `setlocale` de bash (langues non installées sur la machine de test) filtrés.

## Risks / Trade-offs

- [Thunderbird ouvert pendant une réinstallation de langue] → le processus garde ses fichiers ouverts, à relancer ; cas rare (changement de langue d'Ubuntu), l'échange lui-même reste sûr.
- [Une future version déplace `res/multilocale.txt`] → langue illisible : l'archive extraite est refusée avec un échec nommé (D6), pas de réinstallation en boucle ; à corriger alors dans le module.
- [Liste des langues figée] → une langue ajoutée par Mozilla retombe sur `ll` ou `en-US` jusqu'à la mise à jour de la constante.
- [Slug d'un dictionnaire changé sur addons.thunderbird.net] → Thunderbird n'installe pas le dictionnaire ; l'adresse se corrige dans `config/thunderbird/policies.json`.
- [Dépendances système de l'archive (GTK3, ALSA…) absentes] → présentes sur Ubuntu Desktop ; constaté en VM (tâche 2.1) : Thunderbird s'ouvre.
- [Pas de vérification de signature de l'archive] → téléchargement HTTPS depuis Mozilla, comme la doc ; la signature GPG (`.asc`) pourrait être ajoutée plus tard.

## Migration Plan

Aucune. Retour arrière : `rm -rf ~/.local/share/thunderbird ~/.local/bin/thunderbird ~/.local/share/applications/thunderbird.desktop`, `sudo rm /etc/thunderbird/policies/policies.json` (le profil `~/.config/thunderbird` n'est pas touché).
