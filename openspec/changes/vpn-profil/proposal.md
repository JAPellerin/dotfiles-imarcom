## Why

Le module `vpn` (vague 3) n'installe qu'OpenVPN et son greffon NetworkManager : l'import du profil était reporté faute de savoir ce que fournit l'équipe TI (décision du 23 sept 2026), et reste une étape manuelle. C'est désormais connu (24 sept 2026) : un profil `jpellerin.ovpn` autonome (autorité, certificat, clé privée et `tls-crypt` intégrés, `auth-user-pass`, UDP), plus un identifiant et un **mot de passe fixe**. L'utilisateur a joint le profil à l'élément **`op://Imarcom/VPN`**, qui porte déjà l'identifiant et le mot de passe (coffre `Imarcom` : coffre de travail, à lui seul). Tout ce qu'il faut pour créer la connexion est donc dans 1Password : le script peut le faire sans étape manuelle.

## What Changes

- **`vpn`** : quand aucune connexion VPN OpenVPN n'existe, le module **importe le profil** lu dans 1Password dans NetworkManager, sous le nom **« Imarcom »**, avec l'identifiant et le mot de passe de l'élément ; le mot de passe est gardé par NetworkManager dans sa configuration système (lisible par root seulement — décision de l'utilisateur, 25 sept 2026), sans invite à la connexion. La connexion n'est **pas** démarrée automatiquement : l'utilisateur l'active depuis le menu système du bureau.
- Le profil (qui contient une clé privée) et le mot de passe ne sont **jamais affichés ni journalisés** ; le profil ne transite sur disque que dans un fichier temporaire privé, retiré à la fin dans tous les cas.
- Une connexion OpenVPN déjà présente n'est **jamais modifiée** (« déjà fait », comme aujourd'hui).
- Sans session 1Password ou sans le profil dans l'élément : l'étape manuelle d'import actuelle, sans échec.
- Description du module mise à jour (le profil n'est plus « manuel »).

Hors périmètre (reportés, décision du 24 sept 2026) : reconnexion automatique (`connection.secondaries`, démarrage avec une autre connexion), commande `vpn` ; routage (on garde celui que décrit le profil) ; plusieurs profils.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-vpn` : le profil est importé depuis 1Password au lieu d'être une étape manuelle ; le module crée la connexion quand aucune n'existe.

## Impact

- Modifiés : `modules/65-vpn.sh`, `tests/test-vpn.sh`.
- 1Password : lecture de `op://Imarcom/VPN/username`, `op://Imarcom/VPN/password` et du fichier joint `jpellerin.ovpn`, seulement quand aucune connexion n'existe ; jamais dans `module_check`.
- Écritures système : une connexion NetworkManager, enregistrée par netplan dans `/etc/netplan/90-NM-<uuid>.yaml` (root, 0600 ; relevé en VM le 25 sept 2026) ; certificats et clé extraits du profil par le greffon dans `~/.local/share/networkmanagement/certificates/nm-openvpn/` (0600).
- Réseau : aucun (import local ; la connexion n'est pas démarrée).
- **Module graphique** : validation en VM (import, puis connexion réelle au VPN de l'entreprise).
- Docs : `ROADMAP.md` (vague 4 : `vpn` fait).
