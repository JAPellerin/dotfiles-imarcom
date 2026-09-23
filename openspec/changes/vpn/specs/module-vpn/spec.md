## Purpose

Installer OpenVPN et son intégration au gestionnaire de réseau du bureau, pour que l'utilisateur puisse importer et utiliser le profil VPN de l'entreprise ; la configuration du profil reste manuelle en attendant d'être automatisée.

## ADDED Requirements

### Requirement: OpenVPN et son greffon NetworkManager depuis les dépôts Ubuntu
Le module `vpn` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer `openvpn` et le greffon OpenVPN de NetworkManager pour GNOME depuis les dépôts d'Ubuntu. Le module MUST NOT utiliser de dépôt tiers. Seuls les paquets manquants SHALL être passés à apt.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans OpenVPN
- **THEN** `openvpn` et le greffon sont installés, et l'ajout d'une connexion VPN dans les paramètres réseau du bureau propose OpenVPN et l'import d'un fichier de profil

#### Scenario: Paquets déjà présents, aucun profil
- **WHEN** les paquets sont déjà installés (recommandations du bureau d'Ubuntu) mais qu'aucune connexion VPN OpenVPN n'existe
- **THEN** `module_check` retourne 1, le module s'exécute sans rien passer à apt, et le résumé final demande d'importer le profil

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Profil VPN importé
Le module SHALL n'être « déjà fait » que si les paquets sont installés **et** qu'une connexion VPN OpenVPN existe dans NetworkManager, constatée sans `sudo` ni réseau. Tant qu'aucune n'existe, le module SHALL déclarer l'étape manuelle d'importer le profil fourni par l'équipe TI ; cette étape MUST NOT faire échouer le module. Le module MUST NOT créer ni modifier de connexion VPN.

#### Scenario: Aucun profil
- **WHEN** le module se termine et qu'aucune connexion VPN OpenVPN n'existe
- **THEN** le résumé final demande d'importer le profil VPN de l'entreprise

#### Scenario: Profil déjà importé
- **WHEN** les paquets sont installés et qu'une connexion VPN OpenVPN existe dans NetworkManager
- **THEN** `module_check` retourne 0, le module est sauté et aucune étape manuelle n'est déclarée à ce titre

#### Scenario: Connexion VPN d'un autre type
- **WHEN** seule une connexion VPN d'un autre type (WireGuard, par exemple) existe
- **THEN** `module_check` retourne 1 et l'étape d'import est déclarée
