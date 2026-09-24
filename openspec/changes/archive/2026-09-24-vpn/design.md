## Context

Voir `proposal.md`. Le socle fournit `apt_install`, `pkg_installed`, `manual_step`.

Relevés du 23 sept 2026 dans la VM Ubuntu 26.04 : `openvpn` 2.7.0-1ubuntu1.2, `network-manager-openvpn` et `network-manager-openvpn-gnome` 1.12.5-1 disponibles dans les dépôts d'Ubuntu ; NetworkManager gère le réseau du bureau.
Relevé à la contre-vérification (index apt `resolute`) : `ubuntu-desktop-minimal` **recommande** `network-manager-openvpn-gnome`, qui dépend de `network-manager-openvpn`, qui dépend d'`openvpn` — installés d'office avec le bureau. **Constaté en VM le 24 sept 2026** (snapshot vierge) : les trois paquets sont installés par l'installateur d'Ubuntu (`/var/log/apt/history.log` du 26 août) ; le module n'a rien passé à apt (tâche 2.1).

## Goals / Non-Goals

**Goals :** OpenVPN utilisable depuis les paramètres réseau de GNOME ; étape d'import tant qu'aucun profil n'existe.

**Non-Goals :** lire un profil ou des identifiants dans 1Password ; créer une connexion ; autre client OpenVPN. Reportés (voir la proposition).

## Decisions

### D1. Paquets des dépôts Ubuntu
`apt_install openvpn network-manager-openvpn-gnome` (le second tire `network-manager-openvpn`) : ne passe à apt que ce qui manque — sur un bureau standard, probablement rien. Utile quand même : un poste installé sans les recommandations n'aurait pas le greffon.

### D2. Profil importé : dans le critère « déjà fait », et étape d'import tant qu'il manque
**Décision de l'utilisateur (23 sept 2026, contre-vérification) :** `module_check` = les deux paquets installés **et** une connexion VPN OpenVPN présente dans NetworkManager. Exception assumée à la règle habituelle (« une étape manuelle n'entre pas dans le critère ») : les paquets étant déjà là sur un bureau standard (Context), un critère sans le profil rendrait le module « déjà fait » dès le premier affichage du menu, jamais exécuté, et l'étape d'import ne serait jamais vue. Tant qu'aucun profil n'est importé, le module est précoché dans le menu et son passage rappelle l'étape ; une fois le profil importé, il devient « déjà fait ».
Constat (fonction partagée par `module_check` et `module_configure`) : on cherche une connexion VPN OpenVPN : `nmcli -t -f UUID,TYPE connection show`, puis, pour chaque connexion de type `vpn`, `nmcli -g vpn.service-type connection show uuid <uuid>` contenant `openvpn`. Connexions désignées par leur UUID, pas par leur nom : un nom peut contenir « : », séparateur de la sortie `-t`, un UUID jamais. Dans `module_configure`, aucune → `manual_step "Importer le profil VPN de l'équipe TI : Paramètres > Réseau > VPN > + > Importer depuis un fichier (.ovpn)."`, sans échec. `nmcli` absent ou en erreur → pas de profil constaté : `module_check` faux, étape déclarée (on ne sait pas qu'un profil existe). Lecture seule, sans `sudo` ni réseau — `nmcli connection show` est permis à l'utilisateur de la session ; `module_check` tourne à chaque affichage du menu. Le constat est refait dans `module_configure`, sans variable venue de `module_install` (sous-shells du runner).
Transitoire : le change qui automatisera l'import remplacera l'étape, et le critère restera « profil présent ».

### D3. Tests
`tests/test-vpn.sh` : doublures `dpkg-query`, `run_sudo` (simule `apt-get install`), faux `nmcli` (liste de connexions et types de service lus dans des fichiers, ou en échec) ; fonctions appelées **par `module_call`**. Cas : première application (deux paquets passés à apt) ; **paquets déjà installés, aucun profil → `module_check` à faire**, aucun appel à apt, étape déclarée ; profil OpenVPN présent → `module_check` déjà fait ; aucune connexion → étape déclarée ; connexion `vpn` OpenVPN présente → aucune étape ; connexion `vpn` d'un autre type (WireGuard…) → étape déclarée ; connexion `vpn` au type de service illisible → étape déclarée, et une connexion OpenVPN listée après elle est quand même trouvée (le faux `nmcli` vide son entrée standard : la boucle doit l'en protéger) ; `nmcli` en échec → `module_check` à faire, étape déclarée, module sans échec ; aucune commande `nmcli` qui écrit (`add`, `modify`, `import`) ; `module_check` sur chaque paquet et sur le profil.

## Risks / Trade-offs

- [L'équipe TI a fourni autre chose qu'un profil pour NetworkManager (OpenVPN Connect, OpenVPN 3)] → à trancher au change suivant ; les paquets installés ici ne gênent pas.
- [Module précoché à chaque ouverture du menu tant que le profil n'est pas importé] → voulu (D2) : c'est le rappel ; le décocher suffit pour le sauter.
- [Un profil OpenVPN importé mais inutilisable (mauvais serveur, identifiants)] → le module le tient pour prêt : il constate la présence, pas le bon fonctionnement.

## Migration Plan

Aucune. Retour arrière : `apt remove network-manager-openvpn-gnome network-manager-openvpn openvpn`.
