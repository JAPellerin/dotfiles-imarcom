# module-shell Specification

## Purpose

Installer et configurer le shell interactif du poste : zsh avec oh-my-zsh et Powerlevel10k, une configuration commune bash/zsh, et les fichiers de configuration du dépôt liés dans `~`.

## Requirements

### Requirement: Installation de zsh et de son écosystème
Le module `shell` (groupe `shell`, dépend de `base`, sans session graphique requise) SHALL installer `zsh` depuis les dépôts Ubuntu, puis oh-my-zsh dans `~/.oh-my-zsh`, le thème Powerlevel10k dans `~/.oh-my-zsh/custom/themes/powerlevel10k` et les plugins `zsh-autosuggestions` et `zsh-syntax-highlighting` dans `~/.oh-my-zsh/custom/plugins/`, chacun par clonage de son dépôt GitHub officiel, de façon idempotente.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine sans zsh
- **THEN** `zsh --version` fonctionne et les quatre dépôts sont présents aux emplacements attendus

#### Scenario: Réexécution
- **WHEN** tout est déjà installé
- **THEN** `module_check` retourne 0 et le module est « déjà fait »

### Requirement: Fichiers de configuration liés depuis le dépôt
Le module SHALL déployer, via le helper de liens du socle, `config/shell/zshrc` → `~/.zshrc`, `config/shell/commonrc` → `~/.commonrc` et `config/shell/p10k.zsh` → `~/.p10k.zsh`. `~/.commonrc` MUST rester en syntaxe POSIX (chargé par bash et zsh) et SHALL charger, en dernier, chaque fichier `*.sh` du dossier des fragments `~/.commonrc.d` dans l'ordre lexicographique ; un dossier absent ou vide MUST NOT produire d'erreur ni de message. `~/.bashrc` SHALL rester le fichier fourni par Ubuntu, complété d'une ligne unique (idempotente) qui charge `config/shell/bashrc-extra.sh` (chargement de `.commonrc`, complétion nvm si présente, branche git dans l'invite). `.zshrc` SHALL activer les intégrations `fzf` et `zoxide` seulement si ces commandes sont présentes, sans erreur sinon.

#### Scenario: Déploiement
- **WHEN** le module se termine
- **THEN** les trois liens pointent vers le dépôt, `~/.bashrc` contient une seule ligne chargeant `bashrc-extra.sh`, et `bash -ic 'echo $VAULT_ADDR'` comme `zsh -ic 'echo $VAULT_ADDR'` (shells interactifs : `.bashrc` ne se charge pas en `bash -l` non interactif) affichent la valeur définie dans `.commonrc`

#### Scenario: Outils optionnels absents
- **WHEN** `fzf` ou `zoxide` n'est pas installé
- **THEN** `zsh -ic true` se termine sans message d'erreur

#### Scenario: Fragment chargé
- **WHEN** `~/.commonrc.d/exemple.sh` définit une variable
- **THEN** `bash -ic` comme `zsh -ic` affichent cette valeur, et une définition du fragment l'emporte sur celle de `~/.commonrc`

#### Scenario: Aucun fragment
- **WHEN** `~/.commonrc.d` est absent ou ne contient aucun fichier `.sh`
- **THEN** `bash -ic true` et `zsh -ic true` se terminent sans message d'erreur

### Requirement: zsh comme shell de connexion
Le module SHALL définir zsh comme shell de connexion de l'utilisateur courant (`chsh`, via `sudo` pour ne pas redemander le mot de passe), et SHALL indiquer que le changement prend effet à la prochaine session. `module_check` SHALL vérifier ce shell dans `/etc/passwd`.

#### Scenario: Shell changé
- **WHEN** le module se termine
- **THEN** `getent passwd "$USER"` se termine par le chemin de `zsh` et le résumé mentionne qu'une nouvelle session est nécessaire
