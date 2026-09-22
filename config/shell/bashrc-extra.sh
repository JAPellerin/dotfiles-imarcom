# shellcheck shell=bash disable=SC1091,SC2154  # fichiers sourcés hors dépôt ; debian_chroot vient du .bashrc d'Ubuntu
# config/shell/bashrc-extra.sh — complément bash chargé par ~/.bashrc (celui
# d'Ubuntu, laissé intact : le module `shell` n'y ajoute qu'une ligne).
# Ce qui est commun à bash et zsh vit dans ~/.commonrc (POSIX) ; ici, seulement
# ce qui est propre à bash. Chargé uniquement en shell interactif par .bashrc.

# Configuration commune bash/zsh (PATH, nvm, variables) — voir ~/.commonrc
[ -f "$HOME/.commonrc" ] && . "$HOME/.commonrc"
[ -s "${NVM_DIR:-$HOME/.nvm}/bash_completion" ] && . "${NVM_DIR:-$HOME/.nvm}/bash_completion"   # complétion nvm

# Outils optionnels (installés par le module `cli-tools`) : activés seulement
# s'ils sont là. Formes propres à bash — zshrc a les siennes (`fzf --zsh`).
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"   # `z <dossier>` — https://github.com/ajeetdsouza/zoxide
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"            # Ctrl-R, Ctrl-T, Alt-C — fzf ≥ 0.48

# Branche git dans l'invite : __git_ps1 vient de /usr/lib/git-core/git-sh-prompt (paquet git).
if [ -f /usr/lib/git-core/git-sh-prompt ]; then
    . /usr/lib/git-core/git-sh-prompt
    GIT_PS1_SHOWDIRTYSTATE=1      # * = modifs non indexées, + = indexées
    GIT_PS1_SHOWUNTRACKEDFILES=1  # % = fichiers non suivis
    GIT_PS1_SHOWUPSTREAM=auto     # < > <> = en retard / en avance / divergé de origin
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;33m\]$(__git_ps1 " (%s)")\[\033[00m\]\$ '
fi
