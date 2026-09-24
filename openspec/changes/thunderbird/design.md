## Context

Voir `proposal.md`. Le socle fournit `run`, `ui_spin`, `add_cleanup`, `manual_step`, `log_*`. Pas de helper d'archive : un seul module de la vague en a besoin (règle de la ROADMAP : un helper s'écrit avant la vague quand **plusieurs** modules le partagent).

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Paquet `thunderbird` d'Ubuntu 26.04 (VM) | `2:1snap1-0ubuntu5` : transition vers le snap ; non installé, aucun snap Thunderbird présent |
| Dépôt apt de Mozilla | aucun paquet `thunderbird` |
| `download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=fr` | 302 → `…/thunderbird/releases/156.0.1/linux-x86_64/fr/thunderbird-156.0.1.tar.xz` |
| Doc de Mozilla « Install Thunderbird on Linux » | deux méthodes, système (`/opt/thunderbird`, lien `/usr/local/bin/thunderbird`, `.desktop` dans `/usr/local/share/applications`, **mise à jour = réinstaller**) ou dossier personnel ; `.desktop` publié sur `github.com/mozilla/sumo-kb/…/installing-thunderbird-linux/thunderbird.desktop` (`Exec=thunderbird %u`, `Icon=/opt/thunderbird/chrome/icons/default/default128.png`, `MimeType=x-scheme-handler/mailto;…`, actions `Compose` et `Contacts`) |
| Limite du relevé | le détail de la méthode « dossier personnel » n'a pas pu être lu (page rendue par JavaScript) : les emplacements de D2 sont une décision de ce design, à comparer à la page (tâche 2.1) |

## Goals / Non-Goals

**Goals :** archive officielle, sans `sudo`, mise à jour intégrée fonctionnelle, lanceur avec icône, rien de retéléchargé sur une relance.

**Non-Goals :** comptes, client de courriel par défaut, snap, PPA.

## Decisions

### D1. Archive par l'adresse de téléchargement de Mozilla, en français
`https://download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=fr` (constante `THUNDERBIRD_URL`) : Mozilla y redirige vers la dernière version publiée. Téléchargée par `curl -fsSL` dans un temporaire (`add_cleanup`), extraite par `tar -xJf` dans un dossier temporaire **créé dans `~/.local/share`** (`mktemp -d ~/.local/share/.thunderbird.XXXXXX`, nettoyé par `add_cleanup`), puis **renommée** à son emplacement final seulement si l'extraction a réussi et contient `thunderbird/thunderbird` : jamais de dossier d'installation à moitié écrit. Le dossier temporaire est sur le même système de fichiers que la destination, si bien que `mv` est un renommage atomique ; extraite sous `/tmp` (souvent un `tmpfs`), l'archive serait **copiée** vers `~/.local/share`, et une coupure en cours de copie laisserait justement un dossier partiel (relevé à la contre-vérification du 23 sept 2026). Un dossier temporaire `~/.local/share/.thunderbird.XXXXXX` qu'une exécution tuée n'a pas pu nettoyer (SIGKILL, coupure de courant ; ≈ 300 Mio) est retiré au début de l'installation suivante (contre-vérification du 24 sept 2026). Langue française, comme le reste du poste.

### D2. Emplacements : `~/.local/share/thunderbird`, `~/.local/bin/thunderbird`, `~/.local/share/applications/thunderbird.desktop`
Dossier d'installation dans `~/.local/share` (données d'application de l'utilisateur, XDG), appartenant à l'utilisateur : la mise à jour intégrée y écrit. Commande par lien symbolique dans `~/.local/bin`, déjà en tête du `PATH` par `commonrc`. Alternative écartée : `/opt/thunderbird` (méthode système de la doc) — la doc elle-même y prévoit une réinstallation à chaque version.

### D3. Lanceur généré depuis un gabarit versionné
`config/thunderbird/thunderbird.desktop` : copie du fichier de Mozilla, où `Exec` et `Icon` portent `@THUNDERBIRD_DIR@`. Le module remplace ce jeton par le chemin absolu d'installation et écrit le résultat dans `~/.local/share/applications/thunderbird.desktop` (fichier, pas lien : un `.desktop` n'interprète ni `~` ni `$HOME`, et `Exec` doit désigner le binaire même si `~/.local/bin` n'est pas dans le `PATH` de la session graphique). `Exec` absolu plutôt que `thunderbird` : la session graphique ne lit pas `~/.commonrc`. Dans `Exec`, le chemin est **entre guillemets** (`Exec="@THUNDERBIRD_DIR@/thunderbird" %u`) : un dossier personnel contenant une espace couperait sinon la commande ; `Icon` est une valeur simple, sans guillemets. Le commentaire d'en-tête du gabarit ne contient jamais le jeton en toutes lettres, sinon il serait remplacé aussi (contre-vérification du 24 sept 2026). `update-desktop-database ~/.local/share/applications` s'il est présent (pour les `MimeType`), sans échec s'il ne l'est pas.
Le lanceur est réécrit seulement si son contenu diffère du gabarit rendu (constat par comparaison).

### D4. `module_check` et découpage
`module_check` : `~/.local/share/thunderbird/thunderbird` exécutable **et** `~/.local/bin/thunderbird` lien vers lui **et** lanceur identique au gabarit rendu. `module_install` : archive (D1) seulement si le binaire manque, puis étape manuelle des comptes quand il vient d'être installé (déclarée **dans `module_install`** : le runner lance chaque fonction dans son propre sous-shell, aucune variable ne passe à `module_configure`). `module_configure` : lien de commande et lanceur (D2, D3), sans réseau — c'est ce qui permet de rétablir un lanceur retiré sans retélécharger.
Ni la version ni la langue d'une installation existante ne sont vérifiées : Thunderbird se met à jour lui-même.

### D4b. Dépendance à `shell`
`MODULE_DEPS="base shell"` : la commande `~/.local/bin/thunderbird` (D2) n'est trouvée dans un terminal que si `~/.local/bin` est dans le `PATH`, ce que fait `~/.commonrc`, posé par `shell` — même raison que `dev-tools` D7 et `cli-tools` D7. Le lanceur n'en dépend pas (`Exec` absolu, D3). Ajouté à la contre-vérification du 23 sept 2026.

### D5. Tests
`tests/test-thunderbird.sh` : `HOME` isolé ; archive `.tar.xz` fabriquée sur place (un faux `thunderbird/thunderbird` qui répond à `--version`, une icône), servie en `file://` par surcharge de `THUNDERBIRD_URL` ; fonctions appelées **par `module_call`**. Cas : première application (dossier installé, appartenant à l'utilisateur, lien de commande, lanceur avec `Exec` (chemin entre guillemets) et `Icon` absolus vers le dossier d'installation, chemin rendu seulement dans `Exec` et `Icon`, aucun `@THUNDERBIRD_DIR@` restant, étape des comptes) ; déjà installé → aucun téléchargement ; lanceur retiré → `module_check` à faire, `module_configure` le rétablit sans téléchargement ; lanceur modifié à la main → rétabli ; archive injoignable ou illisible → échec nommé, aucun dossier `~/.local/share/thunderbird` ni dossier temporaire `~/.local/share/.thunderbird.*` restant ; archive sans `thunderbird/thunderbird` → échec, aucun dossier ; dossier temporaire d'une extraction interrompue → retiré, installation réussie ; dossier personnel avec une espace → installé, `Exec` cité, `module_check` à 0 ; aucun `sudo` appelé ; `module_check` sur chaque condition.

## Risks / Trade-offs

- [Dépendances système de l'archive (GTK3, ALSA…) absentes] → présentes sur Ubuntu Desktop ; constaté en VM (tâche 2.1) : Thunderbird doit s'ouvrir.
- [La méthode « dossier personnel » de la doc diffère de D2] → à comparer à la page en VM ; D2 corrigé avant l'archive si besoin.
- [Pas de vérification de signature de l'archive] → téléchargement HTTPS depuis Mozilla, comme la doc ; la signature GPG (`.asc`) pourrait être ajoutée plus tard.

## Migration Plan

Aucune. Retour arrière : `rm -rf ~/.local/share/thunderbird ~/.local/bin/thunderbird ~/.local/share/applications/thunderbird.desktop` (le profil `~/.thunderbird` n'est pas touché).
