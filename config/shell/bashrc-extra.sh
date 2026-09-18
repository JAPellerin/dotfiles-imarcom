# shellcheck shell=bash disable=SC1091,SC2154  # fichiers sourcés hors dépôt ; debian_chroot vient du .bashrc d'Ubuntu
# config/shell/bashrc-extra.sh — complément bash chargé par ~/.bashrc (celui
# d'Ubuntu, laissé intact : le module `shell` n'y ajoute qu'une ligne).
# Ce qui est commun à bash et zsh vit dans ~/.commonrc (POSIX) ; ici, seulement
# ce qui est propre à bash. Chargé uniquement en shell interactif par .bashrc.

# Configuration commune bash/zsh (PATH, nvm, variables) — voir ~/.commonrc
[ -f "$HOME/.commonrc" ] && . "$HOME/.commonrc"
[ -s "${NVM_DIR:-$HOME/.nvm}/bash_completion" ] && . "${NVM_DIR:-$HOME/.nvm}/bash_completion"   # complétion nvm

# Branche git dans l'invite : __git_ps1 vient de /usr/lib/git-core/git-sh-prompt (paquet git).
if [ -f /usr/lib/git-core/git-sh-prompt ]; then
    . /usr/lib/git-core/git-sh-prompt
    GIT_PS1_SHOWDIRTYSTATE=1      # * = modifs non indexées, + = indexées
    GIT_PS1_SHOWUNTRACKEDFILES=1  # % = fichiers non suivis
    GIT_PS1_SHOWUPSTREAM=auto     # < > <> = en retard / en avance / divergé de origin
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;33m\]$(__git_ps1 " (%s)")\[\033[00m\]\$ '
fi
