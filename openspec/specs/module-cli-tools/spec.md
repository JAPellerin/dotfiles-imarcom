# module-cli-tools Specification

## Purpose

Installer la trousse de ligne de commande utilisée au quotidien (recherche, filtrage interactif, lecture colorée, navigation, git, client PostgreSQL) depuis les dépôts d'Ubuntu, et la rendre réellement utilisable dans les deux shells : noms de commandes rétablis et réglages communs déposés en fragment.

## Requirements

### Requirement: Installation des outils depuis les dépôts Ubuntu
Le module `cli-tools` (groupe `shell`, dépend de `base` et de `shell`, sans session graphique requise) SHALL installer depuis les dépôts Ubuntu, s'ils sont absents : `ripgrep`, `fd-find`, `fzf`, `bat`, `zoxide`, `lazygit` et `postgresql-client`. Aucun dépôt tiers ni téléchargement hors apt MUST être utilisé. L'installation SHALL être idempotente : une réexécution n'installe rien de plus.

#### Scenario: Machine fraîche
- **WHEN** le module s'exécute sur une machine où aucun de ces outils n'est installé
- **THEN** les sept paquets sont installés et `rg`, `fzf`, `zoxide`, `lazygit` et `psql` répondent à `--version`

#### Scenario: Installation partielle
- **WHEN** `ripgrep` et `fzf` sont déjà installés et les autres non
- **THEN** seuls les paquets manquants sont passés à apt, et le module se termine sans erreur

#### Scenario: Réexécution
- **WHEN** tout est déjà installé et configuré
- **THEN** `module_check` retourne 0 et le module est sauté

### Requirement: Noms de commandes bat et fd rétablis
Sur Debian et Ubuntu, les paquets `bat` et `fd-find` installent leurs binaires sous les noms `batcat` et `fdfind` pour éviter une collision avec d'autres paquets. Le module SHALL rendre ces outils accessibles sous leurs noms usuels `bat` et `fd` en créant dans `~/.local/bin` un lien symbolique vers chacun des binaires installés par le système. Ce dossier étant déjà dans le `PATH` par la configuration shell commune, les deux noms SHALL fonctionner aussi bien en shell interactif que dans un script ou un sous-processus. Un lien déjà correct MUST NOT être recréé ; un fichier ordinaire portant ce nom MUST être laissé intact et signalé, sans échec du module, et le module SHALL alors déclarer une étape manuelle — le nom usuel n'étant pas en place, le résumé final doit dire quoi faire plutôt que de laisser le module compter pour réussi.

#### Scenario: Liens créés
- **WHEN** le module se termine sur une machine où `batcat` et `fdfind` viennent d'être installés
- **THEN** `~/.local/bin/bat` et `~/.local/bin/fd` sont des liens vers les binaires du système, et `bat --version` comme `fd --version` fonctionnent

#### Scenario: Utilisable hors shell interactif
- **WHEN** une commande non interactive invoque `bat` (aperçu de `fzf`, script)
- **THEN** la commande est trouvée dans le `PATH` et s'exécute

#### Scenario: Nom déjà pris par un vrai fichier
- **WHEN** `~/.local/bin/fd` existe et n'est pas un lien vers `fdfind`
- **THEN** le module le signale, le laisse intact, se termine sans erreur et déclare une étape manuelle nommant le fichier à retirer

#### Scenario: Binaire introuvable après installation
- **WHEN** le paquet a changé de forme et la commande attendue (`batcat`, `fdfind`) reste introuvable après l'installation
- **THEN** le module échoue en nommant la commande, sans créer de lien

### Requirement: Fragment de configuration shell
Le module SHALL versionner `config/cli-tools/commonrc.sh` et le déployer, par le helper de liens du socle, vers `~/.commonrc.d/cli-tools.sh`, conformément à la convention des fragments. Le fragment MUST être en syntaxe POSIX et SHALL définir les réglages `fzf` communs aux deux shells : commande de recherche par défaut et commande du raccourci « fichier » fondées sur `fd`, et options d'affichage dont un aperçu par `bat`. Le module MUST NOT éditer `config/shell/commonrc`. `module_check` SHALL constater l'état du fragment par le helper de vérification des liens.

#### Scenario: Fragment déployé
- **WHEN** le module se termine
- **THEN** `~/.commonrc.d/cli-tools.sh` est un lien vers le fichier du dépôt, et `bash -ic 'echo $FZF_DEFAULT_COMMAND'` comme `zsh -ic 'echo $FZF_DEFAULT_COMMAND'` affichent une commande fondée sur `fd`

#### Scenario: commonrc intact
- **WHEN** le module s'exécute
- **THEN** `config/shell/commonrc` n'est pas modifié

#### Scenario: Module retiré du poste
- **WHEN** le lien `~/.commonrc.d/cli-tools.sh` est supprimé
- **THEN** les deux shells démarrent sans erreur et sans les réglages `fzf`, et `module_check` signale le module comme « à faire »
