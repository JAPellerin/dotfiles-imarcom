## Context

Voir `proposal.md`. Références actuelles : `GIT_SSH_KEY_REF` et `GIT_SSH_PUB_REF` en tête de `modules/30-git.sh` ; lues seulement quand l'agent de l'application n'est pas disponible **et** que `~/.ssh/id_ed25519` manque (`_git_ssh_key`). La doublure `op` de `tests/test-git.sh` répond aux deux références exactes et refuse toute autre. Relevé en VM (29 sept 2026) : l'agent liste la clé sous le nom « Git SSH Key » (`ssh-add -l`), empreinte `SHA256:ukjG…`, acceptée par Bitbucket après ajout de sa clé publique.

## Goals / Non-Goals

**Goals :** le module lit l'élément sous son nouveau nom ; spec, test et `CLAUDE.md` alignés.

**Non-Goals :** migrer une clé déjà écrite sur disque (laissée intacte, comme aujourd'hui) ; accepter les deux noms (l'ancien n'existe plus dans 1Password).

## Decisions

### D1. Renommage simple, sans repli
Les deux constantes changent ; aucun repli sur l'ancien nom : l'élément a été renommé, pas dupliqué, et un repli masquerait une référence périmée.

### D2. Test
La doublure `op` passe aux nouvelles références ; une lecture de l'ancien nom tombe dans son cas « référence inattendue » et fait échouer le test : le renommage est vérifié par le test existant « sans application, clé absente ».

## Risks / Trade-offs

- [Clé renommée à nouveau plus tard] → même geste : deux constantes, la doublure, la spec.
