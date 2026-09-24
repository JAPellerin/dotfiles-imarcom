## ADDED Requirements

### Requirement: Connexion guidée par 1Password
Le socle SHALL fournir un helper de connexion guidée, pour les applications qui n'acceptent pas de connexion scriptée. Le module lui fournit une sonde qui constate, sans `sudo` ni réseau, que la connexion est faite ; un libellé ; le texte de l'étape manuelle ; et, au choix, un secret à copier (référence 1Password, ou valeur produite par une fonction du module), un identifiant à afficher, une commande qui ouvre l'application et une consigne. Si la sonde réussit d'emblée, le helper MUST NOT lire de secret, ouvrir de fenêtre ni appeler `sudo`. Sinon, il SHALL copier le secret dans le presse-papiers, afficher l'identifiant et la consigne, ouvrir l'application, puis attendre que la sonde réussisse ; au délai écoulé, il SHALL proposer de continuer d'attendre ou de passer. Le secret MUST NOT apparaître à l'écran ni dans le journal. Le presse-papiers MUST être vidé à la fin du parcours dans tous les cas : connexion constatée, étape passée ou script interrompu. Le helper MUST NOT faire échouer le module : sans session 1Password, avec un secret illisible ou un presse-papiers indisponible, ou quand l'utilisateur passe, il SHALL avertir et déclarer l'étape manuelle, puis rendre la main sans erreur. Un module dont l'état attendu comprend cette connexion SHALL inclure la même sonde dans `module_check` et SHALL lancer le parcours dans `module_configure`, après l'installation et la configuration de l'application : tant que la connexion n'est pas faite, le module reste à faire et une relance repropose le parcours.

#### Scenario: Déjà connecté
- **WHEN** la sonde réussit au début du parcours
- **THEN** le helper le signale et se termine, sans lecture dans 1Password, sans fenêtre ouverte et sans `sudo`

#### Scenario: Connexion faite pendant l'attente
- **WHEN** une session 1Password est active, le helper copie le mot de passe, ouvre l'application, et l'utilisateur se connecte
- **THEN** la sonde réussit, le presse-papiers est vidé et aucune étape manuelle n'est déclarée

#### Scenario: Passer
- **WHEN** le délai s'écoule et l'utilisateur choisit de passer
- **THEN** le presse-papiers est vidé, l'étape manuelle est déclarée et le module continue sans erreur

#### Scenario: Interruption
- **WHEN** l'utilisateur interrompt le script pendant l'attente
- **THEN** le presse-papiers est vidé

#### Scenario: Sans session 1Password
- **WHEN** aucune session `op` n'est active et un secret est demandé
- **THEN** le helper avertit, déclare l'étape manuelle, n'ouvre aucune fenêtre et se termine sans erreur

#### Scenario: Connexion passée, module toujours à faire
- **WHEN** l'utilisateur a passé l'étape de connexion d'un module qui emploie le helper
- **THEN** `module_check` de ce module retourne 1 et une relance propose de nouveau le parcours, sans réinstaller l'application

#### Scenario: Secret jamais visible
- **WHEN** le helper copie un mot de passe lu dans 1Password
- **THEN** la valeur ne figure ni dans la sortie du script ni dans son journal, alors que l'identifiant fourni y est affiché

### Requirement: Ouverture détachée d'une application
Le socle SHALL fournir un helper qui lance une application graphique détachée du script : le script n'attend pas l'application, celle-ci n'hérite ni du terminal ni du journal, et la commande lancée est consignée au journal. Si l'application ne peut pas être lancée, le helper SHALL avertir sans faire échouer le module.

#### Scenario: Application lancée
- **WHEN** un module ouvre une application par le helper
- **THEN** le script reprend aussitôt, le journal consigne la commande et ne reçoit aucune sortie de l'application

#### Scenario: Application introuvable
- **WHEN** la commande à lancer n'existe pas
- **THEN** le helper avertit et le module continue sans erreur
