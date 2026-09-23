# shellcheck shell=sh
# config/1password/commonrc.sh — fragment déposé par le module `1password` quand
# l'application de bureau est installée, lié en ~/.commonrc.d/1password.sh et
# chargé par ~/.commonrc en bash comme en zsh : syntaxe POSIX uniquement.
#
# SSH_AUTH_SOCK vers l'agent SSH de l'application : git et ssh obtiennent les
# clés de 1Password, rien n'est écrit sur disque. Un fragment plutôt qu'une ligne
# ajoutée à ~/.commonrc : `1password` s'exécute avant `shell`, qui remplace
# ~/.commonrc par un lien vers le dépôt — la ligne finissait dans .commonrc.bak
# (vu en VM le 23 sept 2026).
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
