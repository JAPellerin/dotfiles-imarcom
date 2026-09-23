## Why

L'utilisateur se connecte au réseau de l'entreprise par **OpenVPN**. La ROADMAP prévoyait « OpenVPN + NetworkManager, profil `.ovpn` lu dans 1Password », mais au 23 sept 2026 l'utilisateur ne sait plus exactement ce que l'équipe TI lui a transmis pour se connecter (profil, identifiants, méthode). **Décision de l'utilisateur (23 sept 2026) : installer OpenVPN maintenant, laisser la configuration en étape manuelle, et l'automatiser plus tard**, quand l'information sera retrouvée.

## What Changes

- **Module `vpn`** (`modules/65-vpn.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - `openvpn` et le greffon OpenVPN de NetworkManager pour GNOME (`network-manager-openvpn-gnome`, qui tire `network-manager-openvpn`) depuis les dépôts d'Ubuntu, par `apt_install` — les connexions VPN se gèrent alors dans **Paramètres > Réseau > VPN** ;
  - **étape manuelle** tant qu'aucune connexion VPN OpenVPN n'existe dans NetworkManager : importer le profil fourni par l'équipe TI ;
  - **le module reste « à faire » tant qu'aucun profil OpenVPN n'est importé** — décision de l'utilisateur (23 sept 2026, contre-vérification). Sur Ubuntu 26.04, `ubuntu-desktop-minimal` recommande `network-manager-openvpn-gnome`, qui tire `network-manager-openvpn` puis `openvpn` : sur un poste de bureau neuf, les paquets sont très probablement déjà là. Un critère « paquets installés » seul rendrait le module « déjà fait » d'emblée, jamais exécuté, et l'étape d'import ne s'afficherait jamais. Le vrai état attendu est « VPN prêt à l'emploi », donc un profil importé.

Hors périmètre, **reporté** :

- **Profil `.ovpn` et identifiants lus dans 1Password**, import par `nmcli` : à spécer dans un change ultérieur, quand l'utilisateur aura retrouvé le profil et la méthode de connexion (possiblement un autre client que celui de NetworkManager).
- **Client OpenVPN 3 / OpenVPN Connect** : l'intégration à NetworkManager suit la ROADMAP ; à réévaluer avec l'information de l'équipe TI.

## Capabilities

### New Capabilities
- `module-vpn` : le module `vpn` — OpenVPN et son greffon NetworkManager depuis les dépôts d'Ubuntu, import du profil en étape manuelle (configuration automatisée reportée).

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/65-vpn.sh` et `tests/test-vpn.sh`.
- Écritures système (avec `sudo`) : paquets apt.
- Réseau : dépôts d'Ubuntu. Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL ; validation en VM.
- Docs : `ROADMAP.md` (`vpn` : installation faite, configuration reportée).
