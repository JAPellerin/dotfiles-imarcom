#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice : dépend de 1password ; trace s'il voit la session (marqueur de la
# doublure `op`) à l'installation et à la configuration. FIXTURE_SECRET_CLOSE=1 :
# l'installation « fait expirer » la session (retire le marqueur).
MODULE_NAME="secret"
MODULE_DESC="Module factice qui lit 1Password"
MODULE_GROUP="dev"
MODULE_DEPS="1password"
_dir="${FIXTURE_STATE_DIR:-/tmp/dotfiles-fixtures}"
_session() { [[ -f $_dir/op-session ]] && echo oui || echo non; }
module_check() { [[ -f $_dir/secret ]]; }
module_install() {
  log_info "install secret session=$(_session)"
  [[ ${FIXTURE_SECRET_CLOSE:-0} == 1 ]] && rm -f "$_dir/op-session"
  return 0
}
module_configure() { log_info "configure secret session=$(_session)"; touch "$_dir/secret"; }
