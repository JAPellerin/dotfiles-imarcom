## Why

Vague 4 (ROADMAP, décidée le 24 sept 2026) : les applications de la vague 3 se connectent avec l'aide de 1Password, par le parcours guidé que fournit désormais le socle (`guided_login`, change `socle-connexion`, archivé le 24 sept 2026). Aujourd'hui, `rocketchat` installe le client et pré-configure `rocketchat.imarcom.net`, puis laisse la connexion en étape manuelle au résumé : l'utilisateur doit aller chercher lui-même ses identifiants.

Le serveur de l'entreprise n'offre pas d'OAuth : la connexion se fait par le formulaire (identifiant + mot de passe). L'élément 1Password existe déjà : `Imarcom/RocketChat` (type Login), relevé le 24 sept 2026. Aucun réglage du client n'est à reprendre de l'installation Windows (décision de l'utilisateur) : seule la connexion manque.

## What Changes

- **`rocketchat`** : après l'installation et la configuration du client, **connexion guidée** par le helper du socle — identifiant de `op://Imarcom/RocketChat` affiché, mot de passe copié dans le presse-papiers (jamais affiché ni journalisé, vidé à la fin), client ouvert, consigne, attente du signe de connexion dans la configuration du client.
- **« Connecté » entre dans l'état « déjà fait »** (convention du socle) : tant que l'utilisateur n'est pas connecté à `rocketchat.imarcom.net`, `module_check` rend 1 et une relance repropose le parcours, sans rien retélécharger.
- L'étape manuelle « se connecter » n'est plus déclarée d'office à l'installation : seulement si le parcours n'aboutit pas (pas de session 1Password, mot de passe illisible, « Passer »).

Hors périmètre : réglages du client (thème, notifications, serveurs supplémentaires) ; authentification à deux facteurs du serveur, si elle venait à être activée (l'utilisateur la saisit dans le client, le parcours attend simplement la connexion).

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-rocketchat` : connexion guidée par 1Password au lieu de l'étape manuelle ; `module_check` exige la connexion.

## Impact

- Modifiés : `modules/61-rocketchat.sh`, `tests/test-rocketchat.sh`.
- 1Password : lecture de `op://Imarcom/RocketChat/username` et `op://Imarcom/RocketChat/password` pendant le parcours seulement ; jamais dans `module_check`.
- Aucun nouveau paquet, aucune nouvelle écriture système. Réseau : aucun nouveau (le client joint son serveur, comme avant).
- **Module graphique** : validation en VM (connexion réelle au serveur de l'entreprise).
- Docs : `ROADMAP.md` (vague 4 : `rocketchat` fait).
