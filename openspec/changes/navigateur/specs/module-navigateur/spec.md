## Purpose

Installer le ou les navigateurs choisis par l'utilisateur depuis les dépôts officiels de leurs éditeurs, y pré-installer l'extension 1Password et fixer le navigateur par défaut, pour qu'un poste neuf puisse se connecter à GitHub (et au reste) dès le module `git`.

## ADDED Requirements

### Requirement: Choix des navigateurs au début du module
Le module `navigateur` (groupe `apps`, dépend de `base` et `1password`, nécessite une session graphique) SHALL demander, au début de `module_install` et avant toute installation, quels navigateurs installer parmi **Brave**, **Firefox** et **Google Chrome** (sélection multiple, navigateurs déjà installés cochés d'avance). Si Firefox fait partie de la sélection, le module SHALL demander sa langue parmi **comme Ubuntu** (langue détectée depuis la locale du système, affichée dans l'option), **français** et **anglais** ; Brave et Google Chrome suivent la langue du système et ne font l'objet d'aucune question de langue. Conformément au contrat des modules à choix interne, `module_check` SHALL toujours renvoyer « à faire » et chaque exécution SHALL n'installer que ce qui manque parmi les navigateurs choisis. Une sélection vide SHALL terminer `module_install` sans erreur et sans rien installer.

#### Scenario: Première exécution
- **WHEN** aucun navigateur n'est installé et l'utilisateur choisit Brave et Firefox
- **THEN** les deux questions (navigateurs, langue de Firefox) sont posées avant le premier `apt install`, puis Brave et Firefox sont installés sans nouvelle question sur les navigateurs

#### Scenario: Relance
- **WHEN** Brave est déjà installé et l'utilisateur relance le module en gardant Brave coché et en ajoutant Chrome
- **THEN** Brave est proposé coché d'avance, seul Chrome est installé et le module se termine sans erreur

#### Scenario: Sélection vide
- **WHEN** l'utilisateur ne coche aucun navigateur
- **THEN** le module signale qu'il n'y a rien à installer et se termine sans erreur

### Requirement: Installation depuis les dépôts officiels
Chaque navigateur SHALL être installé depuis le dépôt apt officiel de son éditeur, ajouté par le helper apt du socle (clé dans `/etc/apt/keyrings/`, fichier `.sources` deb822) : Brave depuis `brave-browser-apt-release.s3.brave.com` (paquet `brave-browser`), Firefox depuis `packages.mozilla.org/apt` (suite `mozilla`, paquet `firefox`) et Google Chrome depuis `dl.google.com/linux/chrome/deb/` (paquet `google-chrome-stable`, architecture `amd64`). Pour Firefox, le module SHALL écrire l'épinglage apt `/etc/apt/preferences.d/mozilla` (`Pin: origin packages.mozilla.org`, priorité 1000) demandé par Mozilla et SHALL remplacer le paquet de transition d'Ubuntu (`firefox` version `1:1snap1…`) par le paquet de Mozilla s'il est présent. Pour Google Chrome, le module SHALL écrire `repo_add_once="false"` dans `/etc/default/google-chrome` avant l'installation afin que le paquet ne crée pas un second fichier de dépôt.

#### Scenario: Brave
- **WHEN** Brave est choisi
- **THEN** `/etc/apt/sources.list.d/brave-browser.sources` et sa clé sont en place, `brave-browser` est installé et `brave-browser --version` fonctionne

#### Scenario: Firefox sur Ubuntu Desktop
- **WHEN** Firefox est choisi et le paquet de transition `firefox` d'Ubuntu (snap) est installé
- **THEN** l'épinglage est écrit, `apt-cache policy firefox` montre le candidat de `packages.mozilla.org` et le paquet installé est celui de Mozilla (version sans `snap`)

#### Scenario: Google Chrome
- **WHEN** Google Chrome est choisi
- **THEN** `google-chrome-stable` est installé, `/etc/apt/sources.list.d/google-chrome.sources` existe et aucun `google-chrome.list` n'a été créé par le paquet

### Requirement: Firefox en .deb à la place du snap
Une fois le paquet `firefox` de Mozilla installé, le module SHALL retirer le snap `firefox` s'il est présent. Le snap MUST NOT être retiré tant que le `.deb` n'est pas en place ni lorsque Firefox n'est pas choisi. Langue : en **français** (choisi, ou « comme Ubuntu » avec une locale `fr*`), le module SHALL installer `firefox-l10n-fr` et fixer la préférence `intl.locale.requested` à `fr` par stratégie, avec un statut qui laisse l'utilisateur changer de langue dans Firefox ; en **anglais** (choisi, ou « comme Ubuntu » avec une locale `en*`), aucun paquet de langue n'est installé et `firefox-l10n-fr` est retiré s'il était présent ; « comme Ubuntu » avec une autre langue SHALL avertir qu'aucun paquet de langue n'est prévu et laisser Firefox en anglais. La préférence de langue SHALL être déduite du paquet de langue installé (pas d'état séparé).

#### Scenario: Remplacement du snap
- **WHEN** Firefox est choisi et le snap `firefox` est installé
- **THEN** après l'installation du `.deb`, `snap list firefox` échoue et `firefox --version` renvoie la version de Mozilla

#### Scenario: Firefox non choisi
- **WHEN** l'utilisateur choisit Brave seulement
- **THEN** le snap `firefox` n'est pas touché

#### Scenario: Firefox en français
- **WHEN** Firefox est choisi en français
- **THEN** `firefox-l10n-fr` est installé et `/etc/firefox/policies/policies.json` contient la préférence `intl.locale.requested` = `fr`

#### Scenario: Comme Ubuntu, système en anglais
- **WHEN** Firefox est choisi avec « comme Ubuntu » et la locale du système est `en_CA.UTF-8`
- **THEN** aucun paquet de langue n'est installé et la stratégie ne contient pas `intl.locale.requested`

#### Scenario: Retour à l'anglais
- **WHEN** `firefox-l10n-fr` est installé et l'utilisateur relance le module en choisissant « anglais »
- **THEN** `firefox-l10n-fr` est retiré et la préférence `intl.locale.requested` disparaît de la stratégie

### Requirement: Extension 1Password par stratégie
Pour chaque navigateur pris en charge présent sur la machine, `module_configure` SHALL déployer une stratégie d'entreprise qui installe automatiquement l'extension 1Password en mode `normal_installed` (installée au prochain démarrage du navigateur, désactivable par l'utilisateur) : `/etc/brave/policies/managed/1password.json` et `/etc/opt/chrome/policies/managed/1password.json` (extension `aeblfdkhhhdcdjpifhhbdiojplfjncoa` du Chrome Web Store) et `/etc/firefox/policies/policies.json` (extension `{d634138d-c276-4fc8-924b-40a0ea21d284}` depuis `addons.mozilla.org`). Le contenu SHALL provenir de fichiers versionnés dans `config/navigateur/` et l'écriture SHALL être idempotente (fichier réécrit seulement si son contenu change). Un navigateur absent MUST NOT recevoir de stratégie.

#### Scenario: Stratégies écrites
- **WHEN** Brave et Firefox sont installés
- **THEN** `/etc/brave/policies/managed/1password.json` et `/etc/firefox/policies/policies.json` existent avec l'extension 1Password en `normal_installed`, et `/etc/opt/chrome/policies/managed/` n'a pas été créé

#### Scenario: Extension présente au démarrage
- **WHEN** l'utilisateur ouvre Brave pour la première fois après le module
- **THEN** l'extension 1Password est installée et `brave://policy` la liste dans `ExtensionSettings`

#### Scenario: Réexécution
- **WHEN** le module est réexécuté sans changement
- **THEN** aucun fichier de stratégie n'est réécrit et le module se termine sans erreur

### Requirement: Brave Sync guidé
Lorsque Brave est installé et qu'aucune chaîne de synchronisation n'est rejointe, `module_configure` SHALL proposer de rejoindre la chaîne enregistrée dans 1Password : lecture de la graine (24 mots, référence `op://Private/Brave Sync/code`, les 24 premiers mots retenus) par le helper de lecture des secrets, calcul du 25ᵉ mot valable ce jour (nombre de jours écoulés depuis le 10 mai 2022 à 00:00 UTC, arrondi, modulo 2048, index dans la liste de mots BIP39 anglaise versionnée), copie de la phrase de 25 mots dans le presse-papiers, ouverture de Brave sur sa page de configuration de la synchronisation avec la consigne, puis attente jusqu'à ce que la chaîne soit rejointe (constaté dans le profil de Brave) ou que l'utilisateur choisisse de passer. La phrase MUST NOT apparaître à l'écran ni dans le journal ; le presse-papiers SHALL être vidé une fois la chaîne rejointe. Sans session 1Password ou sans item dans le coffre, le module SHALL avertir, déclarer l'étape manuelle et continuer sans erreur. Si Brave a déjà rejoint une chaîne, rien n'est proposé.

#### Scenario: Chaîne rejointe
- **WHEN** Brave vient d'être installé, une session 1Password est active et l'utilisateur colle le code dans Brave puis confirme
- **THEN** le module constate la chaîne dans le profil, vide le presse-papiers et poursuit sans étape manuelle

#### Scenario: Vingt-cinquième mot
- **WHEN** le module calcule le 25ᵉ mot à une date donnée
- **THEN** le mot est celui affiché pour cette date par Brave pour la même graine (index = jours arrondis depuis le 10 mai 2022 modulo 2048 dans la liste BIP39)

#### Scenario: Passer
- **WHEN** l'utilisateur choisit de passer l'étape
- **THEN** le module continue sans erreur et le résumé final liste « Brave Sync : rejoindre la chaîne » comme étape manuelle

#### Scenario: Déjà synchronisé
- **WHEN** le profil de Brave montre une chaîne déjà rejointe
- **THEN** aucune lecture dans 1Password n'a lieu et aucune fenêtre n'est ouverte

#### Scenario: Sans session 1Password
- **WHEN** aucune session `op` n'est active
- **THEN** le module avertit, déclare l'étape manuelle et se termine sans erreur

### Requirement: Navigateur par défaut
Lorsqu'un seul navigateur est choisi, le module SHALL le définir comme navigateur par défaut. Lorsque plusieurs sont choisis, le module SHALL demander lequel devient le navigateur par défaut, sauf si le défaut courant est déjà l'un d'eux. Le réglage SHALL passer par `xdg-settings` et être vérifié par `xdg-settings get default-web-browser`.

#### Scenario: Un seul navigateur
- **WHEN** seul Brave est choisi
- **THEN** `xdg-settings get default-web-browser` renvoie `brave-browser.desktop` sans question

#### Scenario: Plusieurs navigateurs
- **WHEN** Brave et Firefox sont choisis et le défaut courant est Firefox
- **THEN** aucune question n'est posée et Firefox reste le navigateur par défaut

#### Scenario: Défaut hors sélection
- **WHEN** Brave et Chrome sont choisis et le défaut courant est Firefox
- **THEN** le module demande lequel de Brave ou Chrome devient le défaut, puis l'applique
