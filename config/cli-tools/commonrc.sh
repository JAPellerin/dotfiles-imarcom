# shellcheck shell=sh
# config/cli-tools/commonrc.sh — fragment déposé par le module `cli-tools`, lié
# en ~/.commonrc.d/cli-tools.sh et chargé par ~/.commonrc en bash comme en zsh :
# syntaxe POSIX uniquement. Aucune garde `command -v` ici — le lien n'existe que
# si le module est installé, c'est tout l'intérêt d'un lien par fragment.
# Voir openspec/changes/archive/2026-09-22-cli-tools/design.md (D3).
#
# Ce qui s'initialise par shell (`fzf --bash` / `fzf --zsh`, `zoxide init …`) ne
# peut pas vivre ici : c'est dans config/shell/zshrc et bashrc-extra.sh.

# fzf : recherche fondée sur fd, qui respecte .gitignore (donc pas de node_modules
# dans un dépôt) mais voit les fichiers cachés, sauf .git. Aperçu coloré par bat —
# lancé dans un sous-processus non interactif, d'où les liens ~/.local/bin/{bat,fd}
# posés par le module plutôt que des alias.
FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# shellcheck disable=SC2089,SC2090  # les guillemets autour de la commande d'aperçu
# sont lus par fzf, qui découpe lui-même FZF_DEFAULT_OPTS — forme documentée par fzf.
FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always {}"'
# shellcheck disable=SC2090  # même raison : fzf découpe la valeur lui-même
export FZF_DEFAULT_COMMAND FZF_CTRL_T_COMMAND FZF_DEFAULT_OPTS
