## Context

Voir `proposal.md`. Le socle fournit `apt_add_repo`, `apt_install`, `apt_remove`, `pkg_installed`, `manual_step`, `run`, `run_sudo`, `ui_spin`, `log_*`.

Mesures du 23 sept 2026, faites et non supposées :

| Fait | Mesure |
|---|---|
| Suite `resolute` sur `download.docker.com/linux/ubuntu` | présente (`Release` → 200) ; docker-ce 5:29.8.1, containerd.io 2.3.5, buildx 0.37.1, compose 5.5.1 |
| Ubuntu 26.04 dans la doc d'installation | « Ubuntu Resolute 26.04 (LTS) » listée |
| `docker-ce.postinst` | crée le groupe (`groupadd --system docker` si absent) et active `docker.service` et `docker.socket` (`deb-systemd-helper enable`) |
| Complétions | `docker-ce-cli` livre `/usr/share/zsh/vendor-completions/_docker` et `/usr/share/bash-completion/completions/docker` |
| WSL (poste de dev) | Docker 29.8.1 déjà installé par `~/setup-sudo.sh`, `docker.sources` et `docker.asc` en place, utilisateur dans `docker`, service `enabled`/`active`, systemd en PID 1 |
| Contenu du `docker.sources` de la WSL | identique, ligne à ligne, au gabarit d'`apt_add_repo` (même ordre de champs, même `Signed-By`) |

## Goals / Non-Goals

**Goals :** Docker Engine installé selon la doc officielle, utilisable sans `sudo` après réouverture de session ; un `module_check` qui constate l'état réel sans réseau ; sur la WSL, où tout est déjà là, « déjà fait » sans rien réécrire.

**Non-Goals :** `daemon.json`, rootless, pare-feu, `docker login`, tirage d'image par le module (voir la proposition).

## Decisions

### D1. Dépôt par `apt_add_repo`, sans rien de propre au module
`apt_add_repo docker https://download.docker.com/linux/ubuntu/gpg https://download.docker.com/linux/ubuntu auto stable` — l'exemple même qui figure en tête du helper. La clé est armurée, donc `docker.asc`, comme le fait écrire la doc ; `auto` résout `resolute` depuis `/etc/os-release`. Le helper compare avant d'écrire : sur la WSL, où l'ancien script a produit le même fichier, rien n'est réécrit et `apt update` n'est pas relancé.
Alternative rejetée : écrire le `.sources` à la main comme `~/setup-sudo.sh` — ce serait refaire le helper, et CLAUDE.md l'interdit.

### D2. Paquets en conflit : `apt_remove` sur la liste de la doc, avant le dépôt
La liste est reprise telle quelle de la doc (section « Uninstall old versions »). `apt_remove` ne passe à apt que les paquets présents : sur un poste neuf, aucun appel à apt. Placé **avant** `apt_add_repo` et `apt_install`, comme dans la doc. `apt-get remove` (et non `purge`) : `/var/lib/docker` reste en place, ce que la spec exige.
Alternative rejetée par l'utilisateur : refuser d'installer tant qu'un conflit existe.

### D3. Groupe : constaté par `getent group`, ajouté par `usermod -aG`
Critère : `getent group docker` liste `$USER` parmi ses membres (quatrième champ, découpé sur la virgule, comparaison exacte). **Pas `id -nG`** : il donne les groupes du processus, donc de la session, et resterait faux jusqu'à la reconnexion — `module_check` ne serait jamais vrai dans la session de l'installation.
Le groupe est normalement créé par le paquet (mesuré dans le `postinst`). Le module le crée néanmoins s'il manque (`groupadd --system docker`), comme l'indique la doc post-installation, pour ne pas dépendre d'un détail d'empaquetage.
Ajout : `run_sudo usermod -aG docker "$USER"`, seulement si le critère est faux.

### D4. Service : constaté, rétabli seulement s'il le faut
Le `postinst` active déjà `docker.service` et `docker.socket` ; la doc précise que sur Debian et Ubuntu le service démarre au boot par défaut. Le module constate donc `systemctl is-enabled docker` **et** `systemctl is-active docker` ; si l'un manque, `run_sudo systemctl enable --now docker.service containerd.service` (les deux unités que nomme la doc post-installation), puis nouvelle constatation — échec nommé si le service n'est toujours pas actif. Aucun redémarrage d'un service déjà en marche.
`systemctl is-*` se lisent sans `sudo`. Sans systemd (conteneur, WSL sans systemd), ces commandes échouent : le module échoue alors en le disant, ce qui est le bon comportement — Docker Engine n'y démarrerait pas non plus.

### D5. Session à rouvrir : `id -nG` comparé à la base des groupes
Même forme que l'étape de session du module `terminal` (shell de connexion) : si D3 est vrai mais que `id -nG` ne contient pas `docker`, `log_warn` puis `manual_step "Fermer puis rouvrir la session : …"`. Hors du critère « déjà fait », sans échec (transitoire). La doc mentionne `newgrp docker` comme alternative : il n'agit que dans le shell qui le lance, le message renvoie donc à la réouverture de session.
Pas de helper partagé pour l'instant : deux modules, deux constats différents (shell de connexion, groupe) ; factoriser attendra un troisième cas, dans un change à part.

### D6. `module_check`
Vrai si : les cinq paquets sont installés (`pkg_installed`) **et** l'utilisateur est membre de `docker` selon D3 **et** le service est activé et actif selon D4. Tout se lit localement, sans réseau ni `sudo` — `module_check` tourne à chaque affichage du menu.
Le dépôt n'est pas vérifié : `docker-ce` installé prouve qu'il a servi. L'absence des paquets en conflit ne l'est pas non plus. Mesuré le 23 sept 2026 dans les champs `Conflicts`, `containerd.io` exclut `containerd` et `runc`, et `docker-ce` exclut `docker.io` : ceux-là ne peuvent pas coexister avec une installation faite. Les autres (`docker-compose`, `docker-compose-v2`, `docker-doc`, `docker-buildx`, `podman-docker`) ne sont exclus par aucun champ. Ils sont retirés à l'installation, mais un réinstallé plus tard à la main ne ferait pas repasser le module à « à faire ». C'est assumé : ce serait un choix de l'utilisateur, pas un état cassé du module. La session à rouvrir (D5) n'entre pas dans le critère.

### D7. Tests
`tests/test-docker.sh` (nouveau) : doublures `dpkg-query` (fichier de paquets « installés »), `run_sudo` (journalise ; simule `apt-get install`/`remove`, `usermod`, `groupadd`, `systemctl enable --now`), `getent`, `id`, `systemctl` paramétrables par fichiers, `apt_add_repo` remplacé par une doublure qui compte ses appels (le helper a ses propres tests dans `tests/test-apt.sh`).
Cas : première application (retrait vide, dépôt, cinq paquets, `usermod`, service constaté sans `enable`) ; paquet en conflit présent → retiré avant l'installation ; groupe absent → créé ; déjà membre → pas de `usermod` ; service arrêté → `enable --now` puis constaté ; service qui ne démarre pas → échec nommé ; session sans le groupe → étape manuelle et `module_check` vrai ; session à jour → aucune étape ; `module_check` sur chacune de ses conditions ; réexécution → aucun appel `run_sudo`.
Aucune installation réelle, aucun réseau.

## Risks / Trade-offs

- [Le groupe `docker` donne des droits équivalents à root] → assumé, comme la doc post-installation le présente pour un poste de développement ; le mode rootless reste possible plus tard sans défaire ce module.
- [Plages réseau par défaut de Docker en conflit avec un VPN d'entreprise] → aucune valeur fixée (décision de l'utilisateur) ; le module `vpn` (vague 3) ou un besoin constaté ajoutera un `daemon.json` versionné par `install_system_file`.
- [Ports publiés qui contournent ufw] → aucun pare-feu configuré par ce projet ; à reprendre si un module de pare-feu apparaît.
- [La WSL a été installée par l'ancien script] → c'est un avantage : elle sert de cas « déjà fait » réel. Si le module y réécrivait quoi que ce soit, ce serait un défaut d'idempotence à corriger avant la VM.
- [Une mise à jour de Docker change la liste des paquets de la doc] → la liste est une constante du module, alignée sur la doc du 23 sept 2026.

## Migration Plan

Aucune migration sur un poste neuf. Sur la WSL, rien à migrer : le module constate l'installation existante. Retour arrière (doc « Uninstall Docker Engine ») : `apt purge` des cinq paquets, suppression de `/etc/apt/sources.list.d/docker.sources` et `/etc/apt/keyrings/docker.asc`, puis `/var/lib/docker` et `/var/lib/containerd` si l'on veut effacer les données.
