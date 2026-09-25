## MODIFIED Requirements

### Requirement: OpenVPN et son greffon NetworkManager depuis les dépôts Ubuntu
Le module `vpn` (groupe `apps`, dépend de `base` et de `1password`, nécessite une session graphique) SHALL installer `openvpn` et le greffon OpenVPN de NetworkManager pour GNOME depuis les dépôts d'Ubuntu. Le module MUST NOT utiliser de dépôt tiers. Seuls les paquets manquants SHALL être passés à apt.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans OpenVPN
- **THEN** `openvpn` et le greffon sont installés, et l'ajout d'une connexion VPN dans les paramètres réseau du bureau propose OpenVPN et l'import d'un fichier de profil

#### Scenario: Paquets déjà présents, aucun profil
- **WHEN** les paquets sont déjà installés (recommandations du bureau d'Ubuntu) mais qu'aucune connexion VPN OpenVPN n'existe
- **THEN** `module_check` retourne 1 et le module s'exécute sans rien passer à apt

#### Scenario: Sans session graphique
- **WHEN** le runner s'exécute là où aucune session graphique n'est disponible
- **THEN** le module est annoncé « non disponible ici » et n'est pas exécuté

#### Scenario: Lancé seul
- **WHEN** l'utilisateur lance `setup.sh vpn` sans autre module
- **THEN** le module `1password` est exécuté avant lui

### Requirement: Profil VPN importé
Le module SHALL n'être « déjà fait » que si les paquets sont installés **et** qu'une connexion VPN OpenVPN existe dans NetworkManager, constatée sans `sudo`, sans réseau et sans 1Password. Lorsqu'aucune n'existe et qu'une session 1Password est active, le module SHALL créer dans NetworkManager la connexion OpenVPN « Imarcom » à partir du profil joint à l'élément 1Password du VPN, avec l'identifiant et le mot de passe de cet élément, le mot de passe gardé par NetworkManager dans sa configuration système de sorte que la connexion s'établisse sans invite. La connexion MUST NOT démarrer automatiquement. Le profil et le mot de passe MUST NOT apparaître à l'écran ni dans le journal. À la fin du module, qu'il réussisse, échoue ou soit interrompu, une copie du profil MUST NOT subsister ailleurs que dans la configuration de NetworkManager et dans les fichiers que son greffon en extrait, lisibles par l'utilisateur seul. Si la création échoue ou est interrompue, le module MUST NOT laisser de connexion incomplète ni les fichiers extraits par le greffon, et un échec MUST être nommé. Sans session 1Password, sans autorisation de modifier les connexions système de NetworkManager, ou si l'élément est illisible ou ne porte pas le profil, le module SHALL déclarer l'étape manuelle d'importer le profil et MUST NOT échouer. Le module MUST NOT modifier une connexion VPN OpenVPN existante.

#### Scenario: Import depuis 1Password
- **WHEN** aucune connexion VPN OpenVPN n'existe et qu'une session 1Password est active
- **THEN** la connexion « Imarcom » existe dans NetworkManager avec l'identifiant de l'élément, `module_check` retourne 0, aucune étape manuelle n'est déclarée, et l'activer depuis le menu système établit le VPN sans demander de mot de passe

#### Scenario: Secrets jamais visibles
- **WHEN** le module importe le profil
- **THEN** ni le contenu du profil ni le mot de passe ne figurent dans la sortie du script ni dans son journal, et aucun fichier temporaire du profil ne subsiste

#### Scenario: Pas de démarrage automatique
- **WHEN** la connexion vient d'être créée ou que le poste redémarre
- **THEN** le VPN n'est pas actif tant que l'utilisateur ne l'a pas activé

#### Scenario: Aucun profil
- **WHEN** aucune connexion VPN OpenVPN n'existe et qu'aucune session 1Password n'est active
- **THEN** le résumé final demande d'importer le profil VPN de l'entreprise, aucune connexion n'est créée et le module se termine sans erreur

#### Scenario: Création en échec
- **WHEN** NetworkManager refuse l'import ou l'enregistrement de l'identifiant ou du mot de passe
- **THEN** le module échoue en le nommant, aucune connexion « Imarcom » ne subsiste et les fichiers extraits du profil par le greffon sont retirés

#### Scenario: Interruption pendant la création
- **WHEN** l'utilisateur interrompt le script (Ctrl-C) après l'import du profil et avant que le mot de passe soit enregistré et contrôlé
- **THEN** aucune connexion « Imarcom » ne subsiste, ni fichier temporaire du profil, ni fichier extrait par le greffon, et au passage suivant `module_check` retourne 1

#### Scenario: Profil absent de l'élément
- **WHEN** une session 1Password est active mais que l'élément du VPN ne porte pas le profil (pièce jointe absente, renommée ou vide)
- **THEN** le résumé final demande d'importer le profil VPN, avec un avertissement qui nomme la référence lue, aucune connexion n'est créée, le mot de passe n'est pas lu et le module se termine sans erreur

#### Scenario: Sans autorisation de modifier les connexions système
- **WHEN** la session ne donne pas le droit de modifier les connexions système de NetworkManager (par exemple une session distante)
- **THEN** le résumé final demande d'importer le profil VPN, rien n'est lu dans 1Password, aucune connexion n'est créée et le module se termine sans erreur

#### Scenario: Profil déjà importé
- **WHEN** les paquets sont installés et qu'une connexion VPN OpenVPN existe dans NetworkManager
- **THEN** `module_check` retourne 0, le module est sauté, aucune lecture dans 1Password n'a lieu et la connexion n'est pas modifiée

#### Scenario: Connexion VPN d'un autre type
- **WHEN** seule une connexion VPN d'un autre type (WireGuard, par exemple) existe
- **THEN** `module_check` retourne 1 et le module crée la connexion OpenVPN « Imarcom » (ou déclare l'étape d'import sans session 1Password)
