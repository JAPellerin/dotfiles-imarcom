## Context

Voir `proposal.md`. Relevés du 30 sept 2026 (paquet `solaar` 1.1.19-1 des dépôts d'Ubuntu 26.04, téléchargé et ouvert hors du poste) :

| Fait | Mesure |
|---|---|
| Paquet | `solaar` 1.1.19-1 (`all`), dépôts d'Ubuntu ; dépend de `udev`, `python3-*`, `gir1.2-gtk-3.0`, `gir1.2-ayatanaappindicator3-0.1`, … |
| Accès au récepteur | `/usr/lib/udev/rules.d/60-solaar.rules` : `TAG+="uaccess"` (ACL posées par logind pour l'utilisateur de la session locale) ; groupe `plugdev` seulement si `USE_PLUGDEV_GROUP=true` |
| Question debconf | `solaar/use_plugdev_group`, booléen, **défaut `false`** ; le script d'installation l'écrit dans `/etc/default/solaar` et ne crée le groupe que si `true` |
| Démarrage | `/etc/xdg/autostart/solaar.desktop` : `Exec=solaar --window=hide` (icône dans la barre ; Ubuntu affiche ces icônes par son extension AppIndicator, active par défaut) |
| Lanceur | `/usr/share/applications/solaar.desktop` |
| Réglages | `~/.config/solaar/config.yaml`, par appareil (numéro de série) |

Modèle : un module « paquet apt seul » (`apt_install` dans `module_install`, `pkg_installed` dans `module_check`) ; `apt_install` passe `DEBIAN_FRONTEND=noninteractive`.

## Goals / Non-Goals

**Goals :** Solaar installé, démarré avec la session, accès aux récepteurs sans configuration.

**Non-Goals :** réglages des périphériques (décision de l'utilisateur, 30 sept 2026) ; groupe `plugdev` (utile seulement pour un accès par SSH) ; Solaar dans le dock ; règles de touches de Solaar (limitées sous Wayland).

## Decisions

### D1. `apt_install solaar`, question debconf à sa valeur par défaut
`module_install` : `apt_install solaar`. En mode non interactif, `solaar/use_plugdev_group` garde `false` : accès par les ACL de la session (`uaccess`), aucun groupe, aucune réouverture de session. Pas de `debconf-set-selections` : la valeur par défaut est celle voulue, la fixer n'ajouterait qu'un appel `sudo`.
Alternative écartée : groupe `plugdev` + `ensure_user_in_group` (accès par SSH, sans usage ; réouverture de session exigée).

### D2. `module_check` et `module_configure`
`module_check` = `pkg_installed solaar`. `module_configure` : `return 0`. Le démarrage avec la session et les règles udev viennent du paquet : rien à vérifier en plus. Aucune étape manuelle : le réglage des appareils n'est pas un état attendu du module.

### D3. Métadonnées
`MODULE_NAME="solaar"`, `MODULE_DESC="Solaar (périphériques Logitech ; dépôts Ubuntu)"` (sans virgule ni « | »), `MODULE_GROUP="bureau"`, `MODULE_DEPS="base"`, `MODULE_NEEDS_GUI=1` (application de la session graphique ; sans intérêt dans la WSL).

### D4. Tests (`tests/test-solaar.sh`)
Doublures `dpkg-query` (fichier) et `apt-get` (ajoute les paquets, trace ses appels), `sudo` factice ; fonctions par `module_call`. Cas : `module_check` 1 sans le paquet ; `module_install` → `solaar` installé ; `module_check` 0 ; relance → aucun `apt-get install` ; métadonnées (`NEEDS_GUI`, groupe, description acceptée par `module_meta`).

## Risks / Trade-offs

- [VM sans périphérique USB] → validation en VM limitée à l'installation, au démarrage et à l'icône ; détection des appareils constatée sur le laptop.
- [Récepteur Bolt ou appareil Bluetooth récent mal pris en charge par la version d'Ubuntu] → à constater sur le laptop ; Solaar amont publie aussi un PPA, hors périmètre tant que la version d'Ubuntu suffit.

## Migration Plan

Aucune. Retour arrière : `apt remove solaar`.
