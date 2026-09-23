## Purpose

Installer OpenVPN et son intégration au gestionnaire de réseau du bureau, pour que l'utilisateur puisse importer et utiliser le profil VPN de l'entreprise ; la configuration du profil reste manuelle en attendant d'être automatisée.

## ADDED Requirements

### Requirement: OpenVPN et son greffon NetworkManager depuis les dépôts Ubuntu
Le module `vpn` (groupe `apps`, dépend de `base`, nécessite une session graphique) SHALL installer `openvpn` et le greffon OpenVPN de NetworkManager pour GNOME depuis les dépôts d'Ubuntu. Aucun dépôt tiers MUST être utilisé. Seuls les paquets manquants SHALL être passés à apt.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans OpenVPN
- **THEN** `openvpn` et le greffon sont installés, et l'ajout d'une connexion VPN dans les paramètres réseau du bureau propose OpenVPN et l'import d'un fichier de profil

#### Scenario: Déjà installé
- **WHEN** les paquets sont installés
- **THEN** `module_check` retourne 0 et le module est sauté

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

### Requirement: Import du profil déclaré comme étape manuelle
Tant qu'aucune connexion VPN OpenVPN n'existe dans NetworkManager, le module SHALL déclarer l'étape manuelle d'importer le profil fourni par l'équipe TI. Le module MUST NOT créer ni modifier de connexion VPN. Cette étape MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Aucun profil
- **WHEN** le module se termine et qu'aucune connexion VPN OpenVPN n'existe
- **THEN** le résumé final demande d'importer le profil VPN de l'entreprise

#### Scenario: Profil déjà importé
- **WHEN** une connexion VPN OpenVPN existe déjà dans NetworkManager
- **THEN** aucune étape manuelle n'est déclarée à ce titre
