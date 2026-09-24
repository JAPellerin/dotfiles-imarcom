## Why

La vague 4 (ROADMAP, décidée le 24 sept 2026) fait connecter par le script trois applications de la vague 3 — Rocket.Chat, Thunderbird, Spotify — avec l'aide de 1Password. Aucune de ces applications n'accepte une connexion scriptée (ni jeton, ni API) : la seule voie est un **parcours guidé** — le script prépare le secret, ouvre l'application, donne la consigne et attend un signe sur disque que la connexion est faite. Ce parcours existe déjà, mais **écrit en dur dans `navigateur`** pour Brave Sync (validé en VM le 21 sept 2026). La règle de la ROADMAP s'applique : un helper employé par plusieurs modules d'une vague s'écrit **avant** elle, dans un change à part.

Décisions de l'utilisateur (exploration du 24 sept 2026) :

- 1Password aide **par le presse-papiers**, sur le modèle de Brave Sync : le mot de passe lu par `op_read` y est copié, l'identifiant est affiché, l'utilisateur colle dans l'application. Pas de lien profond vers l'élément dans l'app 1Password : il est ignoré quand la fenêtre est déjà ouverte (constaté le 18 sept 2026).
- **« Connecté » fait partie de l'état « déjà fait »** du module qui emploie le parcours : tant que la connexion n'est pas faite, le module reste « à faire » et une relance repropose le parcours (comme `1password` et `vpn`).
- **Brave Sync est migré sur le helper** dans ce change : un seul parcours dans le code, éprouvé tout de suite sur le cas dont il est tiré.

## What Changes

- **Nouveau `lib/connexion.sh`**, chargé par `setup.sh` :
  - `guided_login` — parcours de connexion guidé : sonde fournie par le module (si elle réussit déjà, rien n'est fait) ; secret lu dans 1Password (`--secret op://…`) ou produit par une fonction du module (`--secret-fn`, pour les secrets calculés comme le code de Brave Sync), copié dans le presse-papiers et **jamais affiché ni journalisé** ; identifiant éventuel affiché en clair ; ouverture de l'application ; consigne numérotée ; attente de la sonde avec, au délai écoulé, le choix « Continuer d'attendre » / « Passer » ; presse-papiers vidé à la fin **dans tous les cas** (connexion constatée, « Passer », interruption). **Jamais bloquant** : sans session 1Password, secret illisible, presse-papiers indisponible ou « Passer » → avertissement et étape manuelle, sans échec du module.
  - `open_detached <commande…>` — lance une application détachée du script (sorties vers `/dev/null`, commande tracée au journal), sans échec si elle ne démarre pas.
- **`navigateur`** : Brave Sync passe par `guided_login` (la graine et le 25ᵉ mot restent calculés par le module, fournis par `--secret-fn`) ; Brave s'ouvre par `open_detached`. Le presse-papiers est désormais vidé aussi quand l'utilisateur passe l'étape ou interrompt le script.
- **`1password`** : ouverture des réglages de l'app par `open_detached` (comportement inchangé).
- Aucun module de la vague 3 ne change ici : `rocketchat`, `thunderbird` et `spotify` emploieront le helper dans leurs propres changes.

Hors périmètre :

- **Les parcours de Rocket.Chat, Thunderbird et Spotify** (sondes, éléments 1Password, consignes) : un change par module, ensuite.
- **Remplissage automatique** dans les applications : 1Password pour Linux ne remplit pas les applications de bureau ; seule son extension de navigateur remplit les pages web (cas de Spotify, dans son propre change).
- **Parcours de connexion de `1password` lui-même** (intégration CLI, agent SSH) : il n'a pas de secret à copier et attend l'app, pas une application tierce ; il garde sa forme.

## Capabilities

### New Capabilities
_Aucune._

### Modified Capabilities
- `module-contract` : nouvelles exigences « Connexion guidée par 1Password » et « Ouverture détachée d'une application ».
- `module-navigateur` : l'exigence « Brave Sync guidé » vide le presse-papiers aussi sur « Passer » et sur interruption.

## Impact

- Nouveaux `lib/connexion.sh` et `tests/test-connexion.sh` ; `setup.sh` charge le nouveau fichier.
- Modifiés : `modules/25-navigateur.sh` (Brave Sync, ouverture de Brave), `modules/10-1password.sh` (ouverture des réglages), `tests/test-navigateur.sh`, `tests/test-1password.sh` au besoin.
- Paquet `wl-clipboard` (dépôts d'Ubuntu) installé par le helper à la première copie s'il manque, comme le fait Brave Sync aujourd'hui.
- Réseau : aucun nouveau. Les tests restent hors ligne.
- Validation en VM : Brave Sync (non-régression) et ouverture des réglages de 1Password.
- Docs : `CLAUDE.md` (liste des helpers et convention « connexion dans `module_check` »), `ROADMAP.md` (`socle-connexion` fait).
