#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice valide : dépend de « base », déclare une étape manuelle, jamais « déjà fait ».
MODULE_NAME="valide"
MODULE_DESC="Module factice conforme"
MODULE_GROUP="dev"
MODULE_DEPS="base autre"
MODULE_NEEDS_GUI=1
FUITE_INTERNE="ne doit pas apparaître dans le runner"
module_check() { return 1; }
# module_install crée un fichier temporaire et l'enregistre au nettoyage : il doit
# avoir disparu à la fin de module_call (test-module.sh).
module_install() {
  local tmp
  tmp=$(mktemp -t dotfiles-fixture-valide.XXXXXX)
  printf '%s' "$tmp" >"${FIXTURE_STATE_DIR:-/tmp}/valide.tmp-path"
  add_cleanup "rm -f '$tmp'"
  printf 'install-%s\n' "$MODULE_NAME"
}
module_configure() { manual_step "Activer quelque chose à la main"; }
