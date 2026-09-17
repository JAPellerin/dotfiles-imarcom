#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# Factice invalide : MODULE_DESC absent.
MODULE_NAME="sans-desc"
MODULE_GROUP="systeme"
MODULE_DEPS=""
module_check() { return 1; }
module_install() { :; }
module_configure() { :; }
