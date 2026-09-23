## Context

Voir `proposal.md`. Le socle fournit `apt_install`, `pkg_installed`, `manual_step`.

Relevés du 23 sept 2026 dans la VM Ubuntu 26.04 : `openvpn` 2.7.0-1ubuntu1.2, `network-manager-openvpn` et `network-manager-openvpn-gnome` 1.12.5-1 disponibles dans les dépôts d'Ubuntu ; NetworkManager gère le réseau du bureau.

## Goals / Non-Goals

**Goals :** OpenVPN utilisable depuis les paramètres réseau de GNOME ; étape d'import tant qu'aucun profil n'existe.

**Non-Goals :** lire un profil ou des identifiants dans 1Password ; créer une connexion ; autre client OpenVPN. Reportés (voir la proposition).

## Decisions

### D1. Paquets des dépôts Ubuntu
`apt_install openvpn network-manager-openvpn-gnome` (le second tire `network-manager-openvpn`). `module_check` : les deux paquets installés.

### D2. Étape d'import : constat par `nmcli`, dans `module_configure`
`module_configure` cherche une connexion VPN OpenVPN : `nmcli -t -f NAME,TYPE connection show`, puis, pour chaque connexion de type `vpn`, `nmcli -g vpn.service-type connection show <nom>` contenant `openvpn`. Aucune → `manual_step "Importer le profil VPN de l'équipe TI : Paramètres > Réseau > VPN > + > Importer depuis un fichier (.ovpn)."`. `nmcli` absent ou en erreur → étape déclarée quand même (on ne sait pas qu'un profil existe). Lecture seule, sans `sudo`. Le constat se fait dans `module_configure` sans variable venue de `module_install` (sous-shells du runner).
Conséquence assumée : une fois les paquets installés, le module est « déjà fait » et n'est plus relancé, donc l'étape n'apparaît qu'aux passages où il s'exécute. C'est transitoire : le change qui automatisera l'import remplacera cette étape.

### D3. Tests
`tests/test-vpn.sh` : doublures `dpkg-query`, `run_sudo` (simule `apt-get install`), faux `nmcli` (liste de connexions et types de service lus dans des fichiers, ou en échec) ; fonctions appelées **par `module_call`**. Cas : première application (deux paquets passés à apt) ; aucune connexion → étape déclarée ; connexion `vpn` OpenVPN présente → aucune étape ; connexion `vpn` d'un autre type (WireGuard…) → étape déclarée ; `nmcli` en échec → étape déclarée, module sans échec ; aucune commande `nmcli` qui écrit (`add`, `modify`, `import`) ; `module_check` sur chaque paquet.

## Risks / Trade-offs

- [L'équipe TI a fourni autre chose qu'un profil pour NetworkManager (OpenVPN Connect, OpenVPN 3)] → à trancher au change suivant ; les paquets installés ici ne gênent pas.
- [Étape visible seulement aux passages du module] → assumé, voir D2.

## Migration Plan

Aucune. Retour arrière : `apt remove network-manager-openvpn-gnome network-manager-openvpn openvpn`.
