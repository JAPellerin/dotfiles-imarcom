## Why

Sur le poste graphique, le module `1password` demande aujourd'hui à l'utilisateur de naviguer lui-même dans l'application (trois réglages dans deux pages), de confirmer « intégration activée ? » au terminal, puis reporte l'activation de l'agent SSH en « étape manuelle restante » que rien ne vérifie. Le projet vise le minimum d'interventions manuelles ; or vérification faite le 18 sept 2026, 1Password ne laisse aucun moyen d'automatiser ces réglages (voir *Impact*), il faut donc réduire la friction autour du seul geste qui reste : quelques clics dans l'app.

## What Changes

- **Ouverture guidée de l'app** : le module lance l'application de bureau directement sur les pages de réglages concernées, via les liens profonds officiels `onepassword://settings/security` puis `onepassword://settings/developers` (ceux utilisés par la doc d'intégration), au lieu d'indiquer un chemin de menus à suivre.
- **Une seule consigne, affichée d'un coup** : se connecter dans l'app si ce n'est pas fait, puis cocher « Unlock using system authentication », « Integrate with 1Password CLI » et « Use the SSH agent ». Plus de question « intégration activée ? ».
- **Attente et vérification automatiques** : le module attend (spinner, délai borné, possibilité d'abandonner ou de basculer sur la connexion en terminal) que l'agent SSH apparaisse (`~/.1password/agent.sock`), puis lance `op signin` une seule fois pour obtenir l'autorisation dans l'app et vérifie la session (`op whoami`). Le résultat est constaté par le script, pas déclaré par l'utilisateur.
- **Fin de l'étape manuelle différée** : l'activation de l'agent SSH n'est plus consignée par `manual_step` ; elle est vérifiée dans le module. Le résumé final n'affiche plus d'étape manuelle pour 1Password.
- **Repli inchangé** : sans application (WSL, session sans GUI) ou sur abandon de l'attente, la connexion en terminal (`op account add` / `op signin`) reste telle quelle.
- **Design D8 et risque associé** de `setup-socle` mis à jour par un renvoi vers ce change (la conclusion « aucune automatisation possible des réglages » y est consignée).

Hors périmètre : rendre `module_check` dépendant de l'agent SSH (le socket n'existe que quand l'app tourne, ce qui casserait l'idempotence du « déjà fait ») ; toute alternative sans app (compte de service, CLI seul sur le laptop).

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-1password` : exigences « Connexion de l'utilisateur » (parcours intégration app : ouverture des pages, attente automatique, abandon) et « Agent SSH » (activation vérifiée dans le module au lieu d'une étape manuelle). La spec de référence est le delta de `setup-socle` (`openspec/changes/setup-socle/specs/module-1password/spec.md`), synchronisée dans `openspec/specs/module-1password/` le 18 sept 2026.

## Impact

- Code : `modules/10-1password.sh` (`_op_connect`, `_op_ssh_agent`), éventuellement un helper d'attente réutilisable dans `lib/` ; `tests/test-op.sh` ou nouveau test pour la boucle d'attente (doublures, sans app).
- Docs : `openspec/changes/setup-socle/design.md` (D8, risque « intégration impossible sans clic »), `CLAUDE.md` (phrase « activation = étape manuelle affichée en fin d'exécution »).
- Contraintes vérifiées (18 sept 2026) qui bornent ce change :
  - la [doc d'intégration app ↔ CLI](https://www.1password.dev/cli/app-integration/) ne prévoit aucune commande ni fichier de configuration pour ces réglages ;
  - les réglages sensibles de l'app sont [signés et remis à leur valeur par défaut s'ils sont modifiés hors de l'app](https://support.1password.com/settings-security/) : écrire `~/.config/1Password/settings/settings.json` est inopérant ;
  - l'app et le CLI ont des stockages de compte séparés ; avec l'intégration activée, le CLI délègue à l'app et `op account add` devient inutile (et nuisible : la doc recommande `op account forget --all`).
- Dépendances système : gestionnaire de schéma `onepassword://` enregistré par le paquet `1password` (`x-scheme-handler/onepassword`), `xdg-open` (présent sur Ubuntu Desktop), PolKit avec agent d'authentification (GNOME).
