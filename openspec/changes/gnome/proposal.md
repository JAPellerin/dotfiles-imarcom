## Why

Dernier module de la vague 5 (ROADMAP : `gnome`, groupe `bureau`, « réglages dconf, thème, clavier, raccourcis »). Sur un poste neuf, l'utilisateur refait à la main les mêmes réglages du bureau : disposition du clavier, thème sombre, fond d'écran, dock, confidentialité. Il les a posés dans la VM de test (29 sept 2026) ; le script doit les amener sur le laptop, et un dock qui présente les applications que les autres modules installent.

## What Changes

- Nouveau module **`gnome`** (70, groupe `bureau`, dépend de `base`, nécessite une session graphique).
- Les réglages de base deviennent les **valeurs par défaut du système** — base dconf du système, fichier versionné dans le dépôt au format de `dconf dump` — et non des réglages imposés (décision de l'utilisateur, 29 sept 2026) : ce que l'utilisateur règle ensuite garde la priorité, et une relance du script ne l'écrase pas.
- Contenu de base, relevé dans la VM : clavier canadien français ; thème sombre (Yaru) ; fond d'écran fourni par Ubuntu, aussi pour l'écran verrouillé ; dock en bas, icônes de 42, masqué automatiquement, sans corbeille ; pas d'icône du dossier personnel sur le bureau ; pas de rapports d'erreur ; localisation coupée ; veilleuse sans horaire automatique ; dossiers en premier dans le sélecteur de fichiers.
- **Dock** fixé par le script : Fichiers, Ghostty, navigateurs (Brave, Firefox, Chrome — seuls les installés s'affichent), 1Password, VS Code, Claude, Thunderbird, Rocket.Chat, Obsidian, Spotify, éditeur de texte de GNOME (ajouté après le test en VM). Liste provisoire, ajustée après un test d'installation complète.
- Le **profil dconf** de l'utilisateur, absent sur Ubuntu 26.04, est créé pour que la base du système soit lue.

Cycle convenu (utilisateur, 29 sept 2026) : cette base → test en VM → ajustements de l'utilisateur → mise à jour du fichier versionné depuis son `dconf dump` ; même chose plus tard sur le laptop.

Hors périmètre : réglages du matériel (pavé tactile, écran, alimentation et mise en veille — réglés sur le laptop) ; réglages que l'extension de pavage d'Ubuntu écrit elle-même ; raccourci du terminal (déjà assuré par le module `terminal` : `Ctrl+Alt+T` passe par `xdg-terminal-exec`) ; verrouillage des réglages (aucun n'est imposé) ; extensions GNOME supplémentaires.

## Capabilities

### New Capabilities
- `module-gnome` : réglages de base du bureau GNOME en valeurs par défaut du système, dock, profil dconf, état du module.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux : `modules/70-gnome.sh`, `config/gnome/` (profil dconf et réglages au format de `dconf dump`), `tests/test-gnome.sh`.
- Écritures système : `/etc/dconf/profile/user`, `/etc/dconf/db/local.d/<fichier>`, base compilée `/etc/dconf/db/local` (`dconf update`).
- Aucune écriture dans la base dconf de l'utilisateur ; aucun réseau.
- `ROADMAP.md` (ligne 70, vague 5).
- Validation en VM : une base utilisateur déjà remplie (VM actuelle) masque les défauts ; le test remet à zéro les clés concernées pour voir la base du système s'appliquer.
