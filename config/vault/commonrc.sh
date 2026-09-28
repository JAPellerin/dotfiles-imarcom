# shellcheck shell=sh
# config/vault/commonrc.sh — fragment déposé par le module `vault`, lié en
# ~/.commonrc.d/vault.sh et chargé par ~/.commonrc en bash comme en zsh : syntaxe
# POSIX uniquement. Le lien n'existe que si le module est installé.
# Voir openspec/changes/archive/2026-09-28-vault/design.md (D3).

# Serveur Vault d'Imarcom (adresse privée : réseau de l'entreprise ou VPN).
export VAULT_ADDR=https://vault.imarcom.net
