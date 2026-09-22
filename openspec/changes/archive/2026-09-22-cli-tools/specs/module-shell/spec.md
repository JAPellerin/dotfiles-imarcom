## MODIFIED Requirements

### Requirement: Fichiers de configuration liés depuis le dépôt
Le module SHALL déployer, via le helper de liens du socle, `config/shell/zshrc` → `~/.zshrc`, `config/shell/commonrc` → `~/.commonrc` et `config/shell/p10k.zsh` → `~/.p10k.zsh`. `~/.commonrc` MUST rester en syntaxe POSIX (chargé par bash et zsh) et SHALL charger, en dernier, chaque fichier `*.sh` du dossier des fragments `~/.commonrc.d` dans l'ordre lexicographique ; un dossier absent ou vide MUST NOT produire d'erreur ni de message. `~/.bashrc` SHALL rester le fichier fourni par Ubuntu, complété d'une ligne unique (idempotente) qui charge `config/shell/bashrc-extra.sh` (chargement de `.commonrc`, complétion nvm si présente, branche git dans l'invite). `.zshrc` **et `bashrc-extra.sh`** SHALL activer les intégrations `fzf` et `zoxide` seulement si ces commandes sont présentes, chacun dans la forme propre à son shell, sans erreur sinon.

#### Scenario: Déploiement
- **WHEN** le module se termine
- **THEN** les trois liens pointent vers le dépôt, `~/.bashrc` contient une seule ligne chargeant `bashrc-extra.sh`, et `bash -ic 'echo $VAULT_ADDR'` comme `zsh -ic 'echo $VAULT_ADDR'` (shells interactifs : `.bashrc` ne se charge pas en `bash -l` non interactif) affichent la valeur définie dans `.commonrc`

#### Scenario: Outils optionnels absents
- **WHEN** `fzf` ou `zoxide` n'est pas installé
- **THEN** `zsh -ic true` et `bash -ic true` se terminent sans message d'erreur

#### Scenario: Outils optionnels présents
- **WHEN** `fzf` et `zoxide` sont installés
- **THEN** dans les deux shells, la fonction de saut de `zoxide` est définie et le raccourci de recherche d'historique de `fzf` est actif

#### Scenario: Fragment chargé
- **WHEN** `~/.commonrc.d/exemple.sh` définit une variable
- **THEN** `bash -ic` comme `zsh -ic` affichent cette valeur, et une définition du fragment l'emporte sur celle de `~/.commonrc`

#### Scenario: Aucun fragment
- **WHEN** `~/.commonrc.d` est absent ou ne contient aucun fichier `.sh`
- **THEN** `bash -ic true` et `zsh -ic true` se terminent sans message d'erreur
