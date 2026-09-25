## Why

Vague 4 (ROADMAP, 24 sept 2026) : les applications de la vague 3 se connectent avec l'aide du script. Aujourd'hui, `spotify` installe le client puis laisse « se connecter » en étape manuelle au résumé.

Le compte Spotify de l'utilisateur est lié à son **compte Google Workspace personnel** (pas celui de travail). Décision de l'utilisateur (25 sept 2026) : se connecter par le **code QR** que le client affiche, scanné avec l'application Spotify de son téléphone — plus rapide que « Continuer avec Google » dans le navigateur (décision du 24 sept 2026, remplacée). Aucun élément 1Password « Spotify » n'existe et aucun n'est nécessaire : le script n'a **aucun secret à copier** ; il ouvre Spotify, donne la consigne et attend que la connexion soit faite.

## What Changes

- **`spotify`** : après l'installation, **connexion guidée** par le helper du socle, **sans secret** — Spotify ouvert, consigne (scanner le code QR avec l'application Spotify du téléphone), attente du signe de connexion dans les préférences du client.
- **« Connecté » entre dans l'état « déjà fait »** (convention du socle) : tant que l'utilisateur n'est pas connecté, `module_check` rend 1 et une relance repropose le parcours, sans rien réinstaller.
- L'étape manuelle « se connecter » n'est plus déclarée d'office à la première installation : seulement si le parcours n'aboutit pas (« Passer »).

Hors périmètre : réglages du client ; connexion par Google ou par mot de passe (possible dans le client, pas guidée).

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-spotify` : connexion guidée au lieu de l'étape manuelle ; `module_check` exige la connexion.

## Impact

- Modifiés : `modules/63-spotify.sh`, `tests/test-spotify.sh`.
- 1Password : aucune lecture par le script.
- Aucun nouveau paquet, aucune nouvelle écriture système, aucun nouveau réseau.
- **Module graphique** : validation en VM (connexion réelle).
- Docs : `ROADMAP.md` (vague 4 : `spotify` fait).
