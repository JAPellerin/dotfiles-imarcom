## Why

Vague 4 (ROADMAP, 24 sept 2026) : Thunderbird doit arriver **« comme l'actuel »** (Thunderbird 156 de l'utilisateur sous Windows), et non vide avec une étape « ajouter les comptes » au résumé. L'actuel, relevé le 24 sept 2026 : un compte Google Workspace de travail (`…@imarcom.net`) en IMAP (`imap.gmail.com`) et SMTP (`smtp.gmail.com:587`), une identité (nom, signature, réponse au-dessus de la citation), les dossiers Gmail (`[Gmail]/Sent Mail`, `Drafts`, `All Mail`, `Trash`), **9 agendas Google** en CalDAV (le sien, « Imarcom », « Imarcom - Télétravail », « Holidays in Canada », 5 agendas de collègues en lecture seule) plus l'agenda local ; aucun filtre ni carnet distant.

Décisions de l'utilisateur (24 et 25 sept 2026) :
- **OAuth2** pour Google (l'actuel emploie un mot de passe d'application, inutile en OAuth2) ;
- la **signature** sera celle de ses courriels envoyés (HTML avec le logo Imarcom), pas l'essai en texte du profil actuel ; **8 agendas** (un agenda de collègue retiré) ;
- les **données personnelles** (nom, adresse, signature, agendas — dont des adresses de collègues) vivent dans **1Password**, élément `op://Imarcom/Thunderbird` : le dépôt est public ;
- compte, identité et agendas sont écrits **une seule fois**, avant le premier lancement : l'utilisateur reste libre de tout modifier ensuite dans Thunderbird, le script ne réécrit rien ;
- la connexion Google se fait dans la fenêtre OAuth de Thunderbird, où l'extension 1Password ne remplit rien : le mot de passe Google Workspace de travail est **copié dans le presse-papiers** par le parcours guidé du socle (`guided_login`), depuis l'élément existant `op://Imarcom/Google Workspace` (champ `password`).

## What Changes

- **`thunderbird`** : tant que le profil ne porte aucun compte, le module
  - crée le profil de Thunderbird s'il n'existe pas encore (Thunderbird jamais lancé) ;
  - y écrit le compte Google de travail (IMAP + SMTP en OAuth2), l'identité (nom, adresse, signature, réponse au-dessus, dossiers Gmail) et les agendas Google lus dans 1Password, Thunderbird fermé ;
  - puis lance la **connexion Google guidée** : adresse affichée, mot de passe copié dans le presse-papiers (jamais affiché ni journalisé, vidé à la fin), Thunderbird ouvert, consigne, attente du jeton OAuth2 dans le profil.
- **« Compte présent et connecté » entre dans l'état « déjà fait »** (convention du socle) : sinon `module_check` rend 1 et une relance reprend là où elle s'était arrêtée, sans retélécharger Thunderbird ni réécrire un compte existant.
- **Jamais bloquant** : sans session 1Password, élément incomplet, Thunderbird resté ouvert, profil qui porte déjà un autre compte, ou « Passer » → avertissement et étape manuelle, sans échec.
- L'étape « ajouter les comptes » n'est plus déclarée d'office à l'installation.

Hors périmètre : filtres, carnets d'adresses, OpenPGP, réglages d'affichage ; importer les courriels de l'actuel (IMAP : tout est sur le serveur) ; Thunderbird comme application de courriel par défaut ; un second compte.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-thunderbird` : compte Google de travail, identité et agendas pré-configurés depuis 1Password, connexion Google guidée ; `module_check` exige compte et connexion ; l'exigence « Comptes déclarés comme étape manuelle » est retirée.

## Impact

- Modifiés : `modules/62-thunderbird.sh`, `tests/test-thunderbird.sh`. Nouveau : `config/thunderbird/compte.js` (gabarit des préférences du compte, sans aucune donnée personnelle).
- 1Password : nouvel élément `op://Imarcom/Thunderbird` à créer par l'utilisateur (champs `nom`, `adresse`, signature en note, agendas en section), plus `op://Imarcom/Google Workspace/password` (existant) ; lus seulement quand le compte manque ; jamais dans `module_check`.
- Écritures : profil de l'utilisateur (`~/.config/thunderbird/`), aucune écriture système nouvelle ; aucun `sudo` nouveau.
- Réseau : le script n'appelle rien lui-même ; le premier lancement sans fenêtre de Thunderbird (création du profil) peut joindre les serveurs de Mozilla le temps de son exécution, puis Thunderbird joint Google à la connexion.
- **Module graphique** : validation en VM avec le vrai compte de travail.
- Docs : `ROADMAP.md` (vague 4 : `thunderbird` fait).
