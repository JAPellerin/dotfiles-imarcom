## 0. Prérequis

- [x] 0.1 (références confirmées par l'utilisateur le 25 sept 2026, profil joint à l'élément VPN selon lui ; reste la vérification par `op`) Élément 1Password : `op read op://Imarcom/VPN/username` répond, `op read op://Imarcom/VPN/password >/dev/null` et `op read op://Imarcom/VPN/jpellerin.ovpn | grep -c '^remote '` réussissent (profil joint à l'élément) ; sinon, joindre le profil ou corriger `VPN_OVPN_REF` dans `design.md` (D1) — **vérifié le 25 sept 2026** : les trois références répondent, `jpellerin.ovpn` joint à l'élément (lignes `client`, `remote`, `<key>` présentes).
- [ ] 0.2 VM (snapshot « vierge », `base`, `vpn`) : depuis le terminal de la session graphique, importer un profil factice par `nmcli connection import` **sans sudo** (polkit), puis `nmcli connection edit` par l'entrée standard (`set vpn.secrets password = …`, `save`) ; relever les droits, l'emplacement des fichiers extraits par le greffon et la syntaxe acceptée ; consigner dans `design.md` (D3) et corriger si besoin

## 1. Module `vpn`

- [ ] 1.1 `modules/65-vpn.sh` : constantes de D1, `MODULE_DESC` (D5), import dans `module_configure` (D1 à D4) — fichier temporaire privé avec nettoyage enregistré avant l'écriture, mot de passe par l'entrée standard, contrôle puis suppression de la connexion sur échec ; en-tête mis à jour (renvoi à ce change) ; vérifier `shellcheck` propre et `./setup.sh --list` → « non disponible ici » dans la WSL
- [ ] 1.2 `tests/test-vpn.sh` : cas de D6, cas existants adaptés ; vérifier `bash tests/run-all.sh` vert et la ligne `shellcheck` de `CLAUDE.md` propre

## 2. Validation en VM et documentation

- [ ] 2.1 VM (snapshot « vierge ») : bootstrap → `base`, `1password`, `vpn` → connexion « Imarcom » dans Paramètres > Réseau > VPN, inactive ; l'activer depuis le menu système → VPN établi **sans invite** (adresse du tunnel, `nmcli connection show --active`) ; `sudo grep -c password /etc/NetworkManager/system-connections/Imarcom.nmconnection` ; aucun `.ovpn` restant dans `$XDG_RUNTIME_DIR` ni `/tmp` ; ni le profil ni le mot de passe dans `~/.local/state/dotfiles/setup-*.log` ; redémarrage → VPN inactif ; relance → « déjà fait », aucun appel `op` ; consigner ici
- [ ] 2.2 `ROADMAP.md` : vague 4, `vpn` fait (date ; reconnexion automatique et commande `vpn` toujours reportées) ; `openspec validate vpn-profil --strict` vert
