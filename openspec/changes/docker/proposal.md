## Why

Les projets de l'utilisateur tournent en conteneurs (Makefile de projet, `docker compose`) : sans moteur Docker, le futur module `projets` (vague 4) ne peut pas lancer son `make setup`. `docker` est le dernier module de la **vague 1** ; il la clôt.

L'utilisateur a écarté Docker Desktop : c'est **Docker Engine** depuis le **dépôt apt officiel de Docker**, selon https://docs.docker.com/engine/install/ubuntu/ puis https://docs.docker.com/engine/install/linux-postinstall/ — ce que faisait déjà `~/setup-sudo.sh` (hors dépôt), à reprendre sous la forme d'un module idempotent.

Relevé le 23 sept 2026 : le dépôt `https://download.docker.com/linux/ubuntu` publie une suite **`resolute`** (Ubuntu 26.04 figure dans les versions prises en charge de la doc) — docker-ce 5:29.8.1, containerd.io 2.3.5, docker-buildx-plugin 0.37.1, docker-compose-plugin 5.5.1.

## What Changes

- **Module `docker`** (`modules/41-docker.sh`, groupe `dev`, dépend de `base`, sans session graphique requise) :
  - **retrait des paquets en conflit** que nomme la doc (`docker.io`, `docker-compose`, `docker-compose-v2`, `docker-doc`, `docker-buildx`, `podman-docker`, `containerd`, `runc`) par `apt_remove` — seulement ceux qui sont présents, donc rien sur un poste neuf ; les données de `/var/lib/docker` ne sont pas touchées ;
  - **dépôt apt officiel** par `apt_add_repo` (clé dans `/etc/apt/keyrings/docker.asc`, `docker.sources` en deb822) — même contenu, au caractère près, que celui que la doc fait écrire ;
  - **les cinq paquets de la doc** : `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` ;
  - **utilisateur dans le groupe `docker`**, pour lancer `docker` sans `sudo` ;
  - **service** : `docker` activé au démarrage et en marche — le paquet s'en charge déjà ; le module le constate, et le rétablit sinon ;
  - **session à rouvrir** : l'appartenance au groupe n'est prise en compte qu'à la prochaine session ; quand la session courante ne l'a pas encore, le module le déclare comme étape manuelle.

Décisions de l'utilisateur (23 sept 2026) :

- **Aucun `/etc/docker/daemon.json`** : réglages par défaut de Docker. Un fichier sera ajouté le jour où un besoin réel se présentera (plages réseau en conflit avec le VPN, place disque des journaux) — en fixer maintenant serait inventer des valeurs.
- **Vérification hors ligne** : le module constate le service et les commandes (`docker`, `docker compose`), sans tirer d'image. `docker run hello-world` est une étape de la validation en VM, pas du module.
- **Paquets en conflit retirés** par `apt_remove`, comme le demande la doc, plutôt qu'un refus d'installer.

Hors périmètre, assumé explicitement :

- **Docker Desktop** — refusé par l'utilisateur.
- **Mode rootless** — la doc post-installation le présente comme une option. Le groupe `docker` suffit à un poste de développement mono-utilisateur, et la doc rappelle qu'il accorde des droits équivalents à root : ce compromis est assumé.
- **Complétions shell** — `docker-ce-cli` livre lui-même `/usr/share/zsh/vendor-completions/_docker` et la complétion bash (vérifié le 23 sept 2026) ; aucun fragment `commonrc.d` n'est nécessaire.
- **Pare-feu (ufw)** — la doc avertit que les ports publiés contournent ufw ; aucun pare-feu n'est configuré par ce projet à ce jour.
- **Connexion à un registre** (`docker login`) — aucun registre privé n'est connu ; le jour venu, le jeton se lira dans 1Password.

## Capabilities

### New Capabilities
- `module-docker` : le module `docker` — Docker Engine depuis le dépôt apt officiel, paquets en conflit retirés, utilisateur dans le groupe `docker`, service actif, session à rouvrir signalée.

### Modified Capabilities
_Aucune._ Les helpers employés (`apt_add_repo`, `apt_install`, `apt_remove`, `manual_step`) existent déjà tels quels.

## Impact

- Nouveaux `modules/41-docker.sh` et `tests/test-docker.sh`.
- Écritures système (avec `sudo`) : `/etc/apt/keyrings/docker.asc`, `/etc/apt/sources.list.d/docker.sources`, paquets apt, appartenance au groupe `docker`, et `systemctl enable --now` seulement si le service n'est pas déjà actif.
- Réseau : dépôt apt de Docker. Les tests restent hors ligne.
- **Module non graphique** : il tourne dans la WSL, où **Docker Engine est déjà installé** par l'ancien `~/setup-sudo.sh` (29.8.1, même dépôt, même `docker.sources`, utilisateur déjà dans le groupe). Le module doit s'y déclarer « déjà fait » sans rien réécrire : c'est le premier cas de validation. La VM (snapshot « vierge ») couvre l'installation depuis zéro.
- Docs : `ROADMAP.md` (`docker` fait, vague 1 close).
