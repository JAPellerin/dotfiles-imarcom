## MODIFIED Requirements

### Requirement: Connexion de l'utilisateur
Après l'installation, le module SHALL vérifier si une session `op` est active (`op whoami`). Sinon, il SHALL guider l'utilisateur pour se connecter : d'abord via l'intégration avec l'application de bureau si elle est installée, sinon via `op account add` (adresse du compte, courriel, clé secrète, mot de passe saisis par l'utilisateur, jamais stockés par le script). Le module MUST échouer si aucune session n'est active à la fin.

Dans le parcours « intégration avec l'app », le module SHALL lancer l'application sur sa page de réglages Security (`onepassword://settings/security`, envoyé une seconde fois après un court délai pour que la page s'affiche au déverrouillage ; la page Developer reste un clic dans l'app, indiqué par la consigne), afficher en une seule fois la consigne complète (se connecter dans l'app si ce n'est pas fait ; activer « Unlock using system authentication », « Integrate with 1Password CLI » et « Use the SSH agent »), puis attendre sans autre question que l'intégration CLI (`developers.cliSharedLockState.enabled` dans `~/.config/1Password/settings/settings.json`) et l'agent SSH (`~/.1password/agent.sock`) soient actifs et le restent pendant un court délai de stabilisation. Il SHALL alors lancer `op signin` une seule fois pour déclencher l'autorisation dans l'app et constater la session par `op whoami`. Le module MUST NOT solliciter l'app pendant l'attente (les signaux sont lus sur disque ; aucune commande `op` dans la boucle) et MUST NOT lancer `op signin` dans ce parcours tant que l'intégration CLI n'est pas activée. Si l'agent SSH est déjà présent au démarrage (app déjà configurée, simplement verrouillée), le module SHALL passer directement à `op signin` sans rouvrir les réglages ni réafficher la consigne. L'attente SHALL être bornée : à l'expiration du délai, l'utilisateur SHALL pouvoir continuer d'attendre, vérifier immédiatement, basculer sur la connexion en terminal ou abandonner. Le module MUST NOT recourir à `op account add` lorsque l'intégration avec l'app est active.

#### Scenario: Intégration avec l'app
- **WHEN** l'application de bureau est installée et l'utilisateur, une fois l'app ouverte sur ses réglages, se connecte et active les trois réglages
- **THEN** le module détecte l'intégration CLI et l'agent SSH, attend leur stabilisation, lance `op signin` une seule fois, `op whoami` réussit et le module se termine avec succès sans avoir posé de question de confirmation

#### Scenario: App déjà configurée, verrouillée
- **WHEN** l'agent SSH est déjà présent au lancement du module et aucune session `op` n'est active
- **THEN** le module lance `op signin` directement (une invite de déverrouillage dans l'app), sans rouvrir les réglages ni afficher la consigne

#### Scenario: Réglage oublié
- **WHEN** `op signin` échoue après la détection des signaux (authentification système non activée, autorisation refusée) ou l'utilisateur demande une vérification sans que l'intégration CLI soit activée
- **THEN** le module affiche l'erreur de `op` ou nomme le réglage manquant, rappelle les réglages à vérifier et propose le menu de reprise sans relancer `op signin` tant que l'utilisateur n'a pas demandé une nouvelle vérification

#### Scenario: Délai d'attente écoulé
- **WHEN** l'intégration CLI et l'agent SSH ne sont pas tous deux actifs dans le délai d'attente
- **THEN** le module propose de continuer d'attendre, de vérifier maintenant, de passer à la connexion en terminal ou d'abandonner, et agit selon le choix

#### Scenario: Connexion manuelle
- **WHEN** l'application de bureau n'est pas installée, ou l'utilisateur a choisi la connexion en terminal
- **THEN** le module lance `op account add` puis `op signin`, et exporte la session pour la suite de l'exécution du runner

#### Scenario: Refus de connexion
- **WHEN** l'utilisateur abandonne l'attente ou interrompt la connexion
- **THEN** le module échoue avec un message expliquant que les modules qui ont besoin de secrets seront sautés

### Requirement: Agent SSH
Lorsque l'application de bureau est installée, le module SHALL configurer `SSH_AUTH_SOCK` vers l'agent 1Password (`~/.1password/agent.sock`) dans la configuration shell commune, de façon idempotente. L'activation de l'agent dans l'app SHALL être obtenue et vérifiée pendant le parcours de connexion (présence du socket) et MUST NOT être reportée en étape manuelle de fin d'exécution. Le module SHALL indiquer que la variable prend effet dans un nouveau terminal.

#### Scenario: Configuration de l'agent
- **WHEN** le module se termine sur le poste graphique
- **THEN** la ligne `SSH_AUTH_SOCK` est présente une seule fois dans la config shell commune, le socket `~/.1password/agent.sock` existe et le résumé final ne contient aucune étape manuelle pour 1Password
