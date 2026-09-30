## Why

L'utilisateur se sert de périphériques Logitech ; sous Windows, il les règle avec Logi Options+, qui n'existe pas sous Linux. L'équivalent est **Solaar**, dans les dépôts d'Ubuntu : réglages des souris et claviers, appairage des récepteurs, état des piles. Demandé le 30 sept 2026 (vague 6).

## What Changes

- Nouveau module **`solaar`** (71, groupe `bureau`, dépend de `base`, nécessite une session graphique) : le paquet `solaar` des dépôts d'Ubuntu, rien d'autre.
- Le paquet apporte lui-même ce qu'il faut (exploration, 30 sept 2026) : règles udev qui donnent l'accès au récepteur à l'utilisateur connecté (ACL de la session, sans groupe), démarrage avec chaque session (fenêtre masquée, icône dans la barre du haut), lanceur dans le menu. Sa question debconf garde sa valeur par défaut (pas de groupe `plugdev`).

Hors périmètre (décision de l'utilisateur) : réglages des périphériques (`~/.config/solaar/config.yaml`, propres à chaque appareil) — réglés sur le laptop, versionnés plus tard si besoin, par le même cycle que `gnome` ; Solaar dans le dock (il vit dans la barre du haut).

## Capabilities

### New Capabilities
- `module-solaar` : Solaar depuis les dépôts d'Ubuntu, accès aux périphériques et démarrage avec la session fournis par le paquet.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux : `modules/71-solaar.sh`, `tests/test-solaar.sh`.
- Modifié : `ROADMAP.md` (tableau).
- Système : paquet `solaar` et ses dépendances Python/GTK ; `/etc/default/solaar` écrit par son script d'installation ; règles udev `60-solaar.rules` ; `/etc/xdg/autostart/solaar.desktop`.
- Validation : la VM Hyper-V ne voit aucun périphérique USB — installation, démarrage et icône en VM ; détection des appareils sur le laptop seulement.
