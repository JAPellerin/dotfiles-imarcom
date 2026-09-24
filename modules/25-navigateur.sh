#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/25-navigateur.sh — navigateurs au choix (Brave, Firefox, Google Chrome)
# depuis les dépôts apt officiels, Firefox en .deb à la place du snap (langue au
# choix), extension 1Password pré-installée par stratégie d'entreprise, Brave Sync
# guidé (code lu dans 1Password, 25ᵉ mot du jour calculé), navigateur par défaut.
#
# Procédures officielles suivies (même dépôt, même clé ; format deb822 + clé
# dans /etc/apt/keyrings/, design D10 du socle) :
#   Brave   : https://brave.com/linux/#debian-ubuntu-mint
#   Firefox : https://support.mozilla.org/kb/install-firefox-linux (dépôt apt + épinglage)
#   Chrome  : https://www.google.com/linuxrepositories/ (dépôt deb + /etc/default/google-chrome)
#   Stratégies : https://chromeenterprise.google/policies/#ExtensionSettings,
#                https://mozilla.github.io/policy-templates/ (ExtensionSettings, Preferences)
#   Brave Sync : brave-core/components/brave_sync/time_limited_words.cc (25ᵉ mot),
#                liste BIP-0039 https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt
# Voir openspec/specs/module-navigateur/spec.md et openspec/changes/archive/2026-09-22-navigateur/design.md.
MODULE_NAME="navigateur"
MODULE_DESC="navigateurs : Brave / Firefox / Chrome (dépôts officiels) ; extension 1Password ; Brave Sync ; navigateur par défaut"
MODULE_GROUP="apps"
MODULE_DEPS="base 1password"
MODULE_NEEDS_GUI=1

# --- Table des navigateurs (D1) --------------------------------------------------------------
NAV_ORDER="brave firefox chrome"
declare -A NAV_LABEL=([brave]="Brave" [firefox]="Firefox" [chrome]="Google Chrome")
declare -A NAV_PKG=([brave]="brave-browser" [firefox]="firefox" [chrome]="google-chrome-stable")
declare -A NAV_DESKTOP=([brave]="brave-browser.desktop" [firefox]="firefox.desktop" [chrome]="google-chrome.desktop")

NAV_BRAVE_KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
NAV_BRAVE_REPO_URL="https://brave-browser-apt-release.s3.brave.com"
NAV_MOZILLA_KEY_URL="https://packages.mozilla.org/apt/repo-signing-key.gpg"
NAV_MOZILLA_REPO_URL="https://packages.mozilla.org/apt"
NAV_CHROME_KEY_URL="https://dl.google.com/linux/linux_signing_key.pub"
NAV_CHROME_REPO_URL="https://dl.google.com/linux/chrome/deb/"

# Préfixe des chemins système (vide en usage réel ; dossier temporaire dans les tests).
NAV_ETC="${NAV_ETC:-}"
NAV_MOZILLA_PREF="$NAV_ETC/etc/apt/preferences.d/mozilla"
NAV_CHROME_DEFAULT="$NAV_ETC/etc/default/google-chrome"
NAV_POLICY_BRAVE="$NAV_ETC/etc/brave/policies/managed/1password.json"
NAV_POLICY_CHROME="$NAV_ETC/etc/opt/chrome/policies/managed/1password.json"
NAV_POLICY_FIREFOX="$NAV_ETC/etc/firefox/policies/policies.json"

# --- Brave Sync (D9) ------------------------------------------------------------------------
# Note sécurisée « Brave Sync Code » du coffre Imarcom (convention op:// assouplie
# le 21 sept 2026) : 24 ou 25 mots, seuls les 24 premiers (la graine) comptent.
NAV_BRAVE_SYNC_REF="op://Imarcom/Brave Sync Code/notesPlain"
NAV_BIP39_LIST="$DOTFILES_DIR/config/navigateur/bip39-english.txt"
# Origine du compteur de jours de Brave : mardi 10 mai 2022 00:00:00 UTC.
NAV_BRAVE_EPOCH=1652140800
NAV_BRAVE_DIR="${NAV_BRAVE_DIR:-$HOME/.config/BraveSoftware/Brave-Browser}"
NAV_BRAVE_PREFS="${NAV_BRAVE_PREFS:-$NAV_BRAVE_DIR/Default/Preferences}"
# Chemin jq de la graine dans Preferences (présente une fois la chaîne rejointe ;
# confirmée en VM le 21 sept 2026, voir design D9).
NAV_BRAVE_SYNC_KEY='.brave_sync_v2.seed'
NAV_SYNC_MANUAL="Brave Sync : rejoindre la chaîne (brave://settings/braveSync/setup ; code dans 1Password « Brave Sync Code », en remplaçant le 25ᵉ mot par celui du jour)"

# Module à choix interne (contrat des modules, D7) : toujours « à faire ». Chaque
# exécution repose la question (navigateurs installés précochés) et n'installe
# que ce qui manque.
module_check() { return 1; }

# --- Questions puis installation ------------------------------------------------------------
module_install() {
  local chosen ids=() id lang="" default
  chosen=$(_nav_ask_browsers) || { log_error "Sélection des navigateurs interrompue."; return 1; }
  if [[ -z $chosen ]]; then
    log_warn "Aucun navigateur choisi : rien à installer."
    return 0
  fi
  mapfile -t ids <<<"$chosen"
  if _nav_in firefox "${ids[@]}"; then
    lang=$(_nav_ask_firefox_lang) || { log_error "Choix de la langue interrompu."; return 1; }
  fi
  default=$(_nav_ask_default "${ids[@]}") || { log_error "Choix du navigateur par défaut interrompu."; return 1; }

  for id in "${ids[@]}"; do
    case $id in
      brave)   _nav_install_brave || return 1 ;;
      firefox) _nav_install_firefox "$lang" || return 1 ;;
      chrome)  _nav_install_chrome || return 1 ;;
    esac
  done
  _nav_set_default "$default"
}

# _nav_in <valeur> <liste...> : vrai si la valeur figure dans la liste.
_nav_in() {
  local needle=$1 item
  shift
  for item in "$@"; do [[ $item == "$needle" ]] && return 0; done
  return 1
}

# _nav_id_of <libellé> : identifiant d'un navigateur d'après son libellé de menu.
_nav_id_of() {
  local id
  for id in $NAV_ORDER; do
    [[ ${NAV_LABEL[$id]} == "$1" ]] && { printf '%s\n' "$id"; return 0; }
  done
  return 1
}

# _nav_installed <id> : navigateur en place. Pour Firefox, le paquet de transition
# d'Ubuntu (« 1:1snap1… », qui installe le snap) ne compte pas : seul le .deb de
# Mozilla vaut.
_nav_installed() {
  case $1 in
    firefox) _nav_firefox_deb ;;
    *) pkg_installed "${NAV_PKG[$1]}" ;;
  esac
}
_nav_firefox_deb() {
  pkg_installed firefox || return 1
  [[ $(dpkg-query -W -f='${Version}' firefox 2>/dev/null) != *snap* ]]
}

# Sélection multiple : navigateurs installés précochés ; Chrome n'existe qu'en amd64.
# Imprime les identifiants choisis, un par ligne (vide si aucun) ; échec si interrompu.
_nav_ask_browsers() {
  local id label options=() selected=() lines line ids=()
  for id in $NAV_ORDER; do
    [[ $id == chrome && $(dpkg --print-architecture) != amd64 ]] && continue
    options+=("${NAV_LABEL[$id]}")
    _nav_installed "$id" && selected+=("${NAV_LABEL[$id]}")
  done
  local presel
  presel=$(IFS=,; printf '%s' "${selected[*]}")
  lines=$(ui_choose_multi "Navigateurs à installer (Espace : cocher, Entrée : valider)" "$presel" "${options[@]}") || return 1
  while IFS= read -r label; do
    [[ -n $label ]] || continue
    id=$(_nav_id_of "$label") || continue
    ids+=("$id")
  done <<<"$lines"
  (( ${#ids[@]} )) && printf '%s\n' "${ids[@]}"
  return 0
}

# _nav_system_lang : code de langue d'Ubuntu (« fr_CA.UTF-8 » → fr ; C/POSIX/vide → en).
_nav_system_lang() {
  local l=${LANG:-}
  l=${l%%.*}; l=${l%%_*}
  [[ -z $l || $l == C || $l == POSIX ]] && l=en
  printf '%s\n' "$l"
}

# Langue de Firefox (D3) : trois options ; imprime le code résolu (fr, en, autre).
# Brave et Chrome suivent la langue du système sans réglage possible sur Linux.
_nav_ask_firefox_lang() {
  local sys choice
  sys=$(_nav_system_lang)
  choice=$(ui_choose "Langue de Firefox (Brave et Chrome suivent celle du système)" \
    "Comme Ubuntu ($sys)" "Français" "Anglais") || return 1
  case $choice in
    Français) printf 'fr\n' ;;
    Anglais)  printf 'en\n' ;;
    *)        printf '%s\n' "$sys" ;;
  esac
}

# Navigateur par défaut (D2) : un seul choisi → lui ; sinon question, sauf si le
# défaut courant est déjà parmi les choisis. Imprime l'identifiant.
_nav_ask_default() {
  local ids=("$@") id current choice labels=()
  if (( ${#ids[@]} == 1 )); then printf '%s\n' "${ids[0]}"; return 0; fi
  current=$(xdg-settings get default-web-browser 2>/dev/null || true)
  for id in "${ids[@]}"; do
    [[ ${NAV_DESKTOP[$id]} == "$current" ]] && { printf '%s\n' "$id"; return 0; }
    labels+=("${NAV_LABEL[$id]}")
  done
  choice=$(ui_choose "Navigateur par défaut" "${labels[@]}") || return 1
  _nav_id_of "$choice"
}

# --- Installation par navigateur ------------------------------------------------------------
_nav_install_brave() {
  apt_add_repo brave-browser "$NAV_BRAVE_KEY_URL" "$NAV_BRAVE_REPO_URL" stable main || return 1
  apt_install brave-browser || return 1
  log_ok "Brave $(brave-browser --version 2>/dev/null | awk '{print $NF}')"
}

# Firefox (D3) : épinglage avant le dépôt, puis le .deb de Mozilla par-dessus le
# paquet de transition d'Ubuntu (déclassement d'époque autorisé par la priorité
# 1000), la langue, et seulement ensuite le retrait du snap.
_nav_install_firefox() {
  local lang=$1
  install_system_file config/navigateur/mozilla.pref "$NAV_MOZILLA_PREF" || return 1
  apt_add_repo mozilla "$NAV_MOZILLA_KEY_URL" "$NAV_MOZILLA_REPO_URL" mozilla main || return 1
  if _nav_firefox_deb; then
    log_ok "Firefox (.deb de Mozilla) déjà installé."
  else
    apt_install_pinned firefox || return 1
    _nav_firefox_deb || { log_error "Le firefox installé n'est pas celui de Mozilla : vérifier $NAV_MOZILLA_PREF et « apt-cache policy firefox »."; return 1; }
  fi
  case $lang in
    fr) apt_install firefox-l10n-fr || return 1 ;;
    en) apt_remove firefox-l10n-fr || return 1 ;;
    *)  log_warn "Langue « $lang » : aucun paquet de langue Firefox prévu par le module, Firefox reste en anglais." ;;
  esac
  _nav_remove_firefox_snap || return 1
  log_ok "Firefox $(firefox --version 2>/dev/null | awk '{print $NF}')"
}

_nav_remove_firefox_snap() {
  command -v snap >/dev/null 2>&1 || return 0
  snap list firefox >/dev/null 2>&1 || return 0
  ui_spin "Retrait du snap firefox (remplacé par le .deb de Mozilla)" run_sudo snap remove firefox
}

# Chrome (D4) : /etc/default/google-chrome écrit avant le paquet, pour que son
# postinst n'ajoute pas un second dépôt (.list) à côté du .sources du socle.
_nav_install_chrome() {
  install_system_file config/navigateur/google-chrome.default "$NAV_CHROME_DEFAULT" || return 1
  apt_add_repo google-chrome "$NAV_CHROME_KEY_URL" "$NAV_CHROME_REPO_URL" stable main amd64 || return 1
  apt_install google-chrome-stable || return 1
  log_ok "Google Chrome $(google-chrome-stable --version 2>/dev/null | awk '{print $NF}')"
}

# Navigateur par défaut via xdg-settings (mimeapps.list : http, https, text/html…).
_nav_set_default() {
  local id=$1 desktop=${NAV_DESKTOP[$1]}
  apt_install xdg-utils || return 1
  if [[ $(xdg-settings get default-web-browser 2>/dev/null) == "$desktop" ]]; then
    log_ok "Navigateur par défaut déjà : ${NAV_LABEL[$id]}"
    return 0
  fi
  run xdg-settings set default-web-browser "$desktop" || return 1
  [[ $(xdg-settings get default-web-browser 2>/dev/null) == "$desktop" ]] \
    || { log_error "xdg-settings n'a pas retenu $desktop comme navigateur par défaut."; return 1; }
  log_ok "Navigateur par défaut : ${NAV_LABEL[$id]}"
}

# --- Configuration : déduite de ce qui est installé (D1) ---------------------------------------
module_configure() {
  _nav_policies || return 1
  _nav_brave_sync
}

# Stratégies d'entreprise (D5) : extension 1Password pour chaque navigateur présent.
_nav_policies() {
  if pkg_installed brave-browser; then
    install_system_file config/navigateur/chromium-1password.json "$NAV_POLICY_BRAVE" || return 1
  fi
  if pkg_installed google-chrome-stable; then
    install_system_file config/navigateur/chromium-1password.json "$NAV_POLICY_CHROME" || return 1
  fi
  if _nav_firefox_deb; then
    _nav_firefox_policy || return 1
  fi
}

# Firefox : stratégie versionnée + préférence de langue déduite du paquet de langue
# installé. Status « user » et non « default » : la valeur par défaut posée par
# la stratégie arrive après le choix de la langue d'interface (jamais à temps,
# vu en VM le 21 sept 2026) ; la valeur utilisateur est écrite dans prefs.js et
# lue tôt au démarrage suivant (en VM, Firefox était en français dès son
# premier lancement).
_nav_firefox_policy() {
  local base="$DOTFILES_DIR/config/navigateur/firefox-policies.json" tmp
  tmp=$(mktemp -t dotfiles-firefox-policies.XXXXXX)
  add_cleanup "rm -f '$tmp'"
  if pkg_installed firefox-l10n-fr; then
    jq '.policies.Preferences["intl.locale.requested"] = {"Value": "fr", "Status": "user"}' "$base" >"$tmp" || return 1
  else
    cp -- "$base" "$tmp" || return 1
  fi
  install_system_file "$tmp" "$NAV_POLICY_FIREFOX"
}

# --- Brave Sync guidé (D9) --------------------------------------------------------------------
# Rejoindre la chaîne ne passe que par l'interface de Brave, et le code de 25 mots
# expire : le 25ᵉ mot encode la date. Parcours de connexion guidée du socle
# (guided_login) : la graine lue dans 1Password et le mot du jour forment le code
# (_nav_brave_code), copié dans le presse-papiers ; Brave s'ouvre ; le script
# reprend quand le profil montre la chaîne. Jamais bloquant : sans session, sans
# note ou sur « Passer », étape manuelle ; presse-papiers vidé dans tous les cas.
# Voir openspec/changes/socle-connexion/design.md (D6).
_nav_brave_sync() {
  pkg_installed brave-browser || return 0
  # Liste BIP39 absente ou incomplète : dépôt cassé, pas une étape de
  # l'utilisateur — le module échoue (vérifié avant le parcours, qui ne fait
  # jamais échouer le module).
  _nav_brave_word25 >/dev/null || return 1
  guided_login "Brave Sync" _nav_brave_synced "$NAV_SYNC_MANUAL" \
    --secret-fn _nav_brave_code \
    --open _nav_open_brave ";" \
    -- "Barre d'adresse : brave://settings/braveSync/setup (ou Menu ☰ › Settings › Sync)." \
       "« I have a sync code » → coller le code (Ctrl-V) → Confirm." \
       "Choisir les données à synchroniser (Sync everything, ou au choix)."
}

# _nav_brave_code : la phrase de 25 mots sur stdout (24 mots de graine lus dans
# 1Password + mot du jour). Avertit et échoue si elle ne peut pas être formée.
_nav_brave_code() {
  local seed word25
  if ! op_session_active; then
    log_warn "Brave Sync : aucune session 1Password, le code ne peut pas être lu."
    return 1
  fi
  if ! seed=$(op_read "$NAV_BRAVE_SYNC_REF" 2>>"$LOG_FILE"); then
    log_warn "Brave Sync : lecture de « $NAV_BRAVE_SYNC_REF » impossible (voir le journal)."
    return 1
  fi
  seed=$(printf '%s' "$seed" | tr -s ' \t\n' '\n' | head -n 24 | paste -sd' ')
  if (( $(printf '%s' "$seed" | wc -w) != 24 )); then
    log_warn "Brave Sync : la note ne contient pas 24 mots de graine."
    return 1
  fi
  word25=$(_nav_brave_word25) || return 1
  printf '%s %s' "$seed" "$word25"
}

# Chaîne rejointe = graine présente dans le profil de Brave (lecture seule).
_nav_brave_synced() {
  [[ -f $NAV_BRAVE_PREFS ]] || return 1
  jq -e "$NAV_BRAVE_SYNC_KEY | strings | length > 0" "$NAV_BRAVE_PREFS" >/dev/null 2>&1
}

# 25ᵉ mot : jours écoulés depuis NAV_BRAVE_EPOCH, arrondis au plus proche (comme
# std::round : le mot bascule à 12:00 UTC), modulo 2048, index dans la liste
# BIP-0039. NAV_NOW (secondes epoch) surcharge la date pour les tests.
_nav_brave_word25() {
  local now=${NAV_NOW:-$(date -u +%s)} days word
  days=$(( (now - NAV_BRAVE_EPOCH + 43200) / 86400 ))
  word=$(sed -n "$(( days % 2048 + 1 ))p" "$NAV_BIP39_LIST")
  [[ -n $word ]] || { log_error "Liste BIP39 introuvable ou incomplète : $NAV_BIP39_LIST"; return 1; }
  printf '%s\n' "$word"
}

# _nav_open_brave : Brave détaché du script (open_detached, lib/connexion.sh). Sans URL :
# Chromium ignore les URL brave:// reçues en ligne de commande (vu en VM le
# 21 sept 2026), la consigne donne le chemin. L'assistant de bienvenue (navigateur
# par défaut, thème, télémétrie) est supprimé par le fichier sentinelle « First
# Run » du profil (mécanisme Chromium) en plus de --no-first-run : le navigateur
# par défaut est déjà réglé par le module.
_nav_open_brave() {
  if [[ ! -e "$NAV_BRAVE_DIR/First Run" ]]; then
    [[ -d $NAV_BRAVE_DIR ]] || { mkdir -p -- "$NAV_BRAVE_DIR" && chmod 0700 "$NAV_BRAVE_DIR"; }
    : >"$NAV_BRAVE_DIR/First Run"
  fi
  open_detached brave-browser --no-first-run
}
