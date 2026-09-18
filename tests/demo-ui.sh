#!/usr/bin/env bash
# tests/demo-ui.sh — démonstration interactive des wrappers de lib/ui.sh.
# À lancer à la main depuis un terminal : `bash tests/demo-ui.sh`.
# Ce n'est pas un test automatisé (gum a besoin du clavier).
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=../lib/ui.sh
source "$DOTFILES_DIR/lib/ui.sh"

ui_header "Démo lib/ui.sh"
log_info "Journal de la démo : $LOG_FILE"

choix=$(ui_choose "Choix unique — un navigateur :" Brave Chrome Firefox)
log_ok "ui_choose → $choix"

selection=$(ui_choose_multi "Sélection multiple — présélection base,git :" "base,git" base git node docker)
log_ok "ui_choose_multi → $(printf '%s' "$selection" | tr '\n' ' ')"

if ui_confirm "Confirmation (défaut oui) — continuer ?"; then log_ok "ui_confirm → oui"; else log_warn "ui_confirm → non"; fi
if ui_confirm "Confirmation (défaut non) — tout effacer ?" non; then log_warn "ui_confirm → oui"; else log_ok "ui_confirm → non"; fi

nom=$(ui_input "Saisie libre — votre prénom :" "Joseph-Antony")
log_ok "ui_input → $nom"

secret=$(ui_password "Saisie masquée — un mot de passe (non conservé) :")
log_ok "ui_password → ${#secret} caractère(s)"

ui_spin "Spinner — commande qui réussit (2 s)" run sleep 2
ui_spin "Spinner — commande qui échoue" run sh -c 'echo "détail de l erreur"; exit 4' || true
cible=$(mktemp -t demo-ui.XXXXXX); rm -f "$cible"
( sleep 2; touch "$cible" ) &
ui_wait "Attente — condition vraie dans 2 s" 10 0.2 test -e "$cible"
rm -f "$cible"
ui_wait "Attente — délai de 3 s écoulé (Ctrl-C pour tester l'abandon)" 3 0.2 false || true
log_info "Fin de la démo."
