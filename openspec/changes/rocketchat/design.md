## Context

Voir `proposal.md`. Le socle fournit `apt_install_deb_url`, `pkg_installed`, `install_system_file`, `manual_step`, et — **après `socle-github`** — `github_release_asset_url`.

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Release 4.17.2 (22 sept) | `rocketchat-4.17.2-linux-amd64.deb`, AppImage, snap, rpm, tar.gz, `latest-linux.yml` |
| Contrôle du `.deb` | `Package: rocketchat`, `Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0` ; `/opt/Rocket.Chat/resources/app.asar`, `/usr/share/applications/rocketchat-desktop.desktop` |
| README, « Default servers » | `servers.json` = objet `{ "Nom": "URL" }` ; lu « only if no other servers have already been added » ; saute l'écran « Connect to server » ; **Linux** : `/home/<user>/.config/Rocket.Chat/` ou `/opt/Rocket.Chat/resources/` |
| Code du client, `src/servers/main.ts` (4.17.2 et `master`, relevé du 24 sept) | lus seulement si aucun serveur n'est enregistré ; `loadAppServers` lit `<resources>/servers.json` (`/opt/Rocket.Chat/resources/`) **sans y toucher** ; `loadUserServers` lit `~/.config/Rocket.Chat/servers.json` puis **le supprime** (`fs.promises.unlink`) ; les deux listes s'additionnent (rangées par URL) : à URL égale, le titre du fichier utilisateur l'emporte |
| Serveur | `https://rocketchat.imarcom.net` → 200 ; `/api/info` : version 8.6, client de bureau minimal 3.9.6 |
| VM, 24 sept 2026 : le client plante au lancement (« quit unexpectedly ») | `kernel.apparmor_restrict_unprivileged_userns = 1` ; journal noyau : `apparmor="DENIED" operation="capable" profile="unprivileged_userns" comm="rocketchat-desk" capname="sys_admin"` puis `trap int3 … in rocketchat-desktop.bin` |
| Profils AppArmor | le paquet `apparmor` d'Ubuntu en fournit un par app Electron connue (`/etc/apparmor.d/obsidian` : `flags=(unconfined) { userns, }`), **aucun pour Rocket.Chat** ; le `.deb` 4.17.2 livre `/opt/Rocket.Chat/resources/apparmor-profile` mais son `postinst` ne l'installe pas, et ce profil vise `/opt/Rocket.Chat/rocketchat-desktop`, devenu un script bash qui lance `rocketchat-desktop.bin` (l'`execpath` du refus) |
| Correctif essayé en VM | profil `rocketchat-desktop` attaché à `/opt/Rocket.Chat/rocketchat-desktop.bin`, `flags=(unconfined) { userns, }`, chargé par `apparmor_parser -r` → le client s'ouvre |
| `postrm` du `.deb` (4.17.1 et 4.17.2, VM 24 sept 2026) | supprime `/etc/apparmor.d/rocketchat-desktop` s'il existe, **à chaque appel, mise à jour comprise** (`upgrade`), sans décharger le profil ; le `postinst` ne le remet pas. Constaté : 4.17.2 → 4.17.1 → 4.17.2, notre profil de ce nom avait disparu, `servers.json` était intact |

## Goals / Non-Goals

**Goals :** client installé, serveur de l'entreprise proposé d'office, rien de retéléchargé sur une relance.

**Non-Goals :** mode serveur unique, réglages imposés, connexion, mise à jour.

## Decisions

### D1. `.deb` par `github_release_asset_url`, motif `-linux-amd64\.deb$`
Même forme qu'`obsidian` D1 et D2 : `pkg_installed rocketchat` d'abord (aucun appel réseau si présent), sinon URL par le helper puis `apt_install_deb_url "$url" rocketchat`.

### D2. `servers.json` du paquet, copié par `install_system_file`
`config/rocketchat/servers.json` : `{ "Imarcom": "https://rocketchat.imarcom.net" }`, copié vers `/opt/Rocket.Chat/resources/servers.json` par `install_system_file` dans `module_configure`, donc après le paquet. Racine surchargeable pour les tests (`ROCKETCHAT_ROOT`, comme `CLAUDE_DESKTOP_ETC`).
Pas l'emplacement utilisateur `~/.config/Rocket.Chat/` (décision initiale, révisée le 24 sept 2026) : le client y supprime le fichier au premier lancement (`loadUserServers`), un lien disparaîtrait et `module_check` ne serait plus jamais satisfait. Le fichier du paquet est relu sans être supprimé : l'état reste constatable. Le fichier n'est déclaré par aucun paquet : `dpkg` ne le retire pas lors d'une mise à jour (constaté en VM le 24 sept 2026 : 4.17.2 → 4.17.1 → 4.17.2, fichier intact, tâche 2.1). Si l'utilisateur retire tous ses serveurs, le client repropose celui de l'entreprise.
Limite documentée : le fichier n'agit que si aucun serveur n'a encore été ajouté. Sur un poste neuf, c'est le cas.

### D3. Étape de connexion dans `module_install`
Comme `obsidian` D3 : déclarée après un `apt_install_deb_url` réussi quand le paquet était absent ; aucune variable transmise à `module_configure` (sous-shells du runner). `module_configure` fait la copie de D2.

### D4. `module_check`
`pkg_installed rocketchat`, puis `cmp -s` de `config/rocketchat/servers.json` avec `$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json` et de `config/rocketchat/apparmor-profile` avec `$ROCKETCHAT_ROOT/etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin` (D6) — comme `claude-desktop`, lu sans `sudo` ni réseau. Le chargement du profil dans le noyau n'est pas constatable sans `root` (`/sys/kernel/security/apparmor`) : le fichier en tient lieu, AppArmor charge `/etc/apparmor.d/` à chaque démarrage.

### D6. Profil AppArmor versionné (ajouté le 24 sept 2026, après le test en VM)
Sans profil qui l'autorise, Ubuntu 26.04 refuse au client les espaces de noms utilisateur et son bac à sable Chromium plante au lancement. `config/rocketchat/apparmor-profile`, sur le modèle des profils d'Ubuntu (`obsidian`) : `profile /opt/Rocket.Chat/rocketchat-desktop.bin flags=(unconfined) { userns, include if exists <local/opt.Rocket.Chat.rocketchat-desktop.bin> }`. `module_configure` le copie vers `/etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin` et, **seulement s'il vient d'être écrit**, le charge par `run_sudo apparmor_parser -r` (une relance sans changement n'appelle pas `sudo`). Si le chargement échoue, le fichier est retiré et le module échoue : `module_check` repasse « à faire », la relance recommence copie et chargement (sinon un fichier présent mais jamais chargé passerait pour fait jusqu'au prochain démarrage).
Nom du fichier et du profil : celui du chemin du binaire (convention AppArmor classique, comme `usr.bin.man`), **pas `rocketchat-desktop`**, que le `postrm` du paquet supprime à chaque mise à jour (révisé le 24 sept 2026, après le test de mise à jour en VM) ; un nom distinct évite aussi de remplacer le profil d'upstream s'il était un jour installé.
Écartés : le profil livré par le paquet (jamais installé par son `postinst`, et attaché au script d'enveloppe et non au binaire) ; `--no-sandbox` dans le lanceur (retire le bac à sable) ; `sysctl kernel.apparmor_restrict_unprivileged_userns=0` (relâche la protection pour tout le système).

### D5. Tests
`tests/test-rocketchat.sh` : `HOME` et racine (`ROCKETCHAT_ROOT`) isolés, doublures `dpkg-query`, `github_release_asset_url`, `apt_install_deb_url` (comme `obsidian`) et `run_sudo` (comme `claude-desktop`) ; fonctions appelées **par `module_call`**. Cas : première application (motif `-linux-amd64\.deb$`, paquet `rocketchat`, fichier copié identique au dépôt, étape de connexion) ; `config/rocketchat/servers.json` est un JSON valide qui désigne `https://rocketchat.imarcom.net` (`jq`) ; déjà installé → aucun appel au helper ; fichier retiré ou différent → `module_check` à faire, `module_configure` le réécrit ; fichier utilisateur `~/.config/Rocket.Chat/servers.json` supprimé par le client → toujours « déjà fait » ; écriture système en échec → `module_configure` échoue ; profil AppArmor (D6) : sous un autre nom que `rocketchat-desktop`, copié et chargé (`apparmor_parser -r` sur la cible), attaché à `rocketchat-desktop.bin` avec `userns`, relance sans changement → aucun chargement, retiré ou différent → à faire puis réécrit et rechargé, chargement en échec → module en échec, fichier retiré, à faire ; recherche ou installation en échec → aucune étape ; `module_check` sur chaque condition.

## Risks / Trade-offs

- [Un serveur a déjà été ajouté à la main] → `servers.json` est ignoré par le client (documenté) ; sans conséquence.
- [Une mise à jour du paquet retire le fichier, ou le paquet livre un jour son propre `servers.json`] → `module_check` repasse « à faire », une relance recopie le fichier ; la survie à une mise à jour est vérifiée en VM (2.1).
- [Une version du `.deb` installe enfin son propre profil, attaché au binaire, ou Ubuntu en ajoute un pour Rocket.Chat] → deux profils attachés au même binaire ; à revoir alors : retirer D6 si ce profil suffit.
- [Un futur `postrm` supprime d'autres fichiers d'`/etc/apparmor.d/`] → `module_check` repasse « à faire », une relance remet le profil.
- [L'adresse du serveur change] → une ligne dans `config/rocketchat/servers.json`.
- [Adresse dans un dépôt public] → adresse publique, joignable depuis Internet ; aucun identifiant n'est versionné.

## Migration Plan

Aucune. Retour arrière : `apt remove rocketchat`, `sudo rm /opt/Rocket.Chat/resources/servers.json`, `sudo apparmor_parser -R /etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin && sudo rm /etc/apparmor.d/opt.Rocket.Chat.rocketchat-desktop.bin`.
