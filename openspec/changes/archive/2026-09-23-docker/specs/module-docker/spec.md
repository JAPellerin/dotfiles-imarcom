## Purpose

Doter le poste d'un moteur de conteneurs utilisable sans `sudo` : Docker Engine depuis le dépôt apt officiel de Docker, selon sa documentation d'installation et de post-installation, pour que les projets puissent lancer leurs services par `docker compose`.

## ADDED Requirements

### Requirement: Docker Engine depuis le dépôt apt officiel
Le module `docker` (groupe `dev`, dépend de `base`, sans session graphique requise) SHALL installer `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` et `docker-compose-plugin` depuis le dépôt apt officiel de Docker, déclaré au format deb822 avec sa clé dans `/etc/apt/keyrings/` par le helper du socle. Docker Desktop, le script de commodité de Docker et les paquets Docker des dépôts Ubuntu MUST NOT être utilisés. Seuls les paquets manquants SHALL être passés à apt.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans Docker
- **THEN** le dépôt de Docker est déclaré, les cinq paquets sont installés, et `docker --version` comme `docker compose version` répondent

#### Scenario: Dépôt déjà déclaré à l'identique
- **WHEN** la clé et le fichier de dépôt de Docker existent déjà avec le contenu que le module écrirait
- **THEN** aucun des deux fichiers n'est réécrit

#### Scenario: Réexécution
- **WHEN** tout est déjà installé et configuré
- **THEN** `module_check` retourne 0 et le module est sauté

### Requirement: Paquets en conflit retirés
Avant d'installer Docker Engine, le module SHALL retirer ceux des paquets que la documentation de Docker désigne comme en conflit — `docker.io`, `docker-compose`, `docker-compose-v2`, `docker-doc`, `docker-buildx`, `podman-docker`, `containerd`, `runc` — qui sont installés, et seulement ceux-là. Les images, conteneurs et volumes présents dans `/var/lib/docker` MUST NOT être supprimés.

#### Scenario: Poste neuf
- **WHEN** aucun de ces paquets n'est installé
- **THEN** rien n'est retiré et l'installation se poursuit

#### Scenario: Paquet Docker d'Ubuntu présent
- **WHEN** `docker.io` est installé
- **THEN** il est retiré avant l'installation de Docker Engine, et `/var/lib/docker` est conservé

### Requirement: Utilisateur dans le groupe docker
Le module SHALL rendre l'utilisateur courant membre du groupe `docker`, afin qu'il puisse lancer `docker` sans `sudo`, en créant le groupe s'il n'existe pas. L'appartenance SHALL être constatée dans la base des groupes du système, et non dans les groupes de la session courante. Un utilisateur déjà membre MUST NOT être réinscrit.

#### Scenario: Utilisateur ajouté
- **WHEN** le module se termine sur une machine où l'utilisateur n'était pas membre du groupe
- **THEN** la base des groupes du système liste l'utilisateur parmi les membres de `docker`

#### Scenario: Déjà membre
- **WHEN** l'utilisateur est déjà membre du groupe `docker`
- **THEN** l'appartenance n'est pas réécrite

### Requirement: Service Docker actif et lancé au démarrage
Le module SHALL constater que le service `docker` est activé au démarrage et en marche. Si l'une des deux conditions manque, il SHALL l'activer et le démarrer, puis le constater de nouveau ; s'il ne se constate toujours pas en marche, le module MUST échouer en le disant. Un service déjà activé et en marche MUST NOT être redémarré.

#### Scenario: Service démarré par le paquet
- **WHEN** l'installation des paquets a déjà activé et démarré le service
- **THEN** le module ne le touche pas

#### Scenario: Service arrêté
- **WHEN** le service `docker` est installé mais arrêté ou désactivé
- **THEN** le module l'active et le démarre, et le constate en marche

#### Scenario: Service impossible à démarrer
- **WHEN** le service ne se constate pas en marche après avoir été démarré
- **THEN** le module échoue avec un message qui nomme le service

### Requirement: Session à rouvrir quand l'appartenance au groupe vient de changer
L'appartenance à un groupe n'est prise en compte qu'à l'ouverture d'une session. Lorsque l'utilisateur est membre de `docker` dans la base des groupes mais que la session courante ne porte pas encore ce groupe, le module SHALL déclarer une étape manuelle demandant de rouvrir la session, afin que l'information figure dans le résumé final. Cette situation étant transitoire, elle MUST NOT faire échouer le module ni entrer dans son critère « déjà fait ».

#### Scenario: Groupe ajouté pendant la session
- **WHEN** l'utilisateur vient d'être ajouté au groupe `docker` et que la session courante ne le porte pas
- **THEN** le module se termine sans erreur et le résumé final demande de rouvrir la session

#### Scenario: Session à jour
- **WHEN** la session courante porte déjà le groupe `docker`
- **THEN** aucune étape manuelle n'est déclarée à ce titre
