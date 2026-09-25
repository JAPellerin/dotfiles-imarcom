#!/usr/bin/env bash
# shellcheck disable=SC2034  # métadonnées lues par le runner
# modules/62-thunderbird.sh — Thunderbird depuis l'archive officielle de Mozilla,
# dans la langue d'Ubuntu, installé dans le dossier personnel (méthode « dossier
# personnel »), dictionnaires anglais (Canada) et français pré-installés par
# stratégie d'entreprise.
#   https://support.mozilla.org/kb/installing-thunderbird-linux
#   https://github.com/thunderbird/policy-templates (ExtensionSettings)
#
# Sur Ubuntu 26.04, le paquet `thunderbird` n'est qu'une transition vers le snap,
# et le dépôt apt de Mozilla ne publie pas Thunderbird : l'archive .tar.xz est le
# seul format officiel. Installée dans ~/.local/share, elle appartient à
# l'utilisateur et la mise à jour intégrée de Thunderbird peut y écrire (D2) ;
# aucun sudo. Commande dans ~/.local/bin (d'où la dépendance à `shell`, D4b),
# lanceur rendu depuis le fichier .desktop de Mozilla (D3). Langue de la version
# tirée de celle d'Ubuntu, constatée dans l'installation et rétablie par une
# réinstallation si elle diffère (D6) ; dictionnaires par stratégie d'entreprise
# dans /etc, seule écriture système du module (D7).
# Compte Google de travail, identité, signature et agendas écrits une seule fois
# dans le profil depuis 1Password, Thunderbird fermé ; profil créé au besoin par
# un premier lancement sans fenêtre ; puis connexion Google guidée (D8 à D14).
# « Compte présent et connecté » fait partie du « déjà fait ».
# Voir openspec/specs/module-thunderbird/spec.md,
# openspec/changes/archive/2026-09-24-thunderbird/design.md (D1 à D7) et
# openspec/changes/thunderbird-comptes/design.md (D8 à D14).
MODULE_NAME="thunderbird"
MODULE_DESC="Thunderbird (archive officielle de Mozilla dans le dossier personnel ; langue d'Ubuntu) ; dictionnaires en-CA et fr ; compte Google et agendas depuis 1Password"
MODULE_GROUP="apps"
MODULE_DEPS="base shell 1password"
MODULE_NEEDS_GUI=1

# Mozilla redirige vers la dernière version publiée (D1) ; @LANG@ devient la
# langue retenue (D6). Surchargeable (tests).
THUNDERBIRD_URL="${THUNDERBIRD_URL:-https://download.mozilla.org/?product=thunderbird-latest&os=linux64&lang=@LANG@}"
# Langues dans lesquelles Mozilla publie Thunderbird (product-details,
# thunderbird_primary_builds.json, relevé du 24 sept 2026) : pas de fr-CA.
THUNDERBIRD_LOCALES="af ar ast be bg br ca cak cs cy da de dsb el en-CA en-GB en-US es-AR es-ES es-MX et eu fi fr fy-NL ga-IE gd gl he hr hsb hu hy-AM id is it ja ka kab kk ko lt lv mk ms nb-NO nl nn-NO pa-IN pl pt-BR pt-PT rm ro ru sk sl sq sr sv-SE th tr uk uz vi zh-CN zh-TW"
THUNDERBIRD_DEFAULT_LOCALE="en-US"
THUNDERBIRD_DIR="$HOME/.local/share/thunderbird"
THUNDERBIRD_BIN="$HOME/.local/bin/thunderbird"
THUNDERBIRD_APPS_DIR="$HOME/.local/share/applications"
THUNDERBIRD_DESKTOP="$THUNDERBIRD_APPS_DIR/thunderbird.desktop"
THUNDERBIRD_DESKTOP_SRC="config/thunderbird/thunderbird.desktop"
# Stratégie d'entreprise des dictionnaires (D7) ; racine surchargeable (tests),
# comme NAV_ETC pour navigateur.
THUNDERBIRD_ETC="${THUNDERBIRD_ETC:-}"
THUNDERBIRD_POLICIES="$THUNDERBIRD_ETC/etc/thunderbird/policies/policies.json"
THUNDERBIRD_POLICIES_SRC="config/thunderbird/policies.json"
# Étapes manuelles, une par cause (D10, D13).
THUNDERBIRD_ACCOUNTS_MANUAL="Ouvrir Thunderbird (menu des applications) et ajouter le compte Google de travail et les agendas."
THUNDERBIRD_CLOSE_MANUAL="Fermer Thunderbird, puis relancer « setup.sh thunderbird » pour écrire le compte de travail."
THUNDERBIRD_LOGIN_MANUAL="Ouvrir Thunderbird (menu des applications) et se connecter au compte Google de travail."

# Élément 1Password du compte (D8) et mot de passe Google Workspace de travail.
THUNDERBIRD_OP_ITEM="op://Imarcom/Thunderbird"
THUNDERBIRD_ADDRESS_REF="$THUNDERBIRD_OP_ITEM/adresse"
THUNDERBIRD_GOOGLE_PASSWORD_REF="op://Imarcom/Google Workspace/password"
# Message de `op read` pour un champ ou une section absents (op 2.39.0, relevé
# du 25 sept 2026), suivi de « '<section>.<champ>' » : seule fin de liste admise.
THUNDERBIRD_OP_NOT_FOUND="does not have a field"
THUNDERBIRD_AGENDAS_MAX=50
# Domaine du compte de travail (D12) : celui de l'entreprise.
THUNDERBIRD_WORK_DOMAIN="imarcom.net"
THUNDERBIRD_ACCOUNT_SRC="config/thunderbird/compte.js"
# Dossiers Gmail, relevés le 25 sept 2026 dans le profil Windows de
# l'utilisateur et dans celui de la VM ; ils suivent la langue du compte Gmail
# (anglais ici) : à corriger pour un compte Gmail dans une autre langue (D11).
THUNDERBIRD_GMAIL_SENT="[Gmail]/Sent Mail"
THUNDERBIRD_GMAIL_DRAFTS="[Gmail]/Drafts"
THUNDERBIRD_GMAIL_ARCHIVE="[Gmail]/All Mail"
THUNDERBIRD_GMAIL_TRASH="[Gmail]/Trash"
THUNDERBIRD_GMAIL_TEMPLATES="Templates"
THUNDERBIRD_CALDAV_URL="https://apidata.googleusercontent.com/caldav/v2"
# Premier lancement sans fenêtre (D9) : délais en secondes, surchargeables (tests).
THUNDERBIRD_START_TIMEOUT="${THUNDERBIRD_START_TIMEOUT:-30}"
THUNDERBIRD_STOP_TIMEOUT="${THUNDERBIRD_STOP_TIMEOUT:-15}"
THUNDERBIRD_POLL_INTERVAL="${THUNDERBIRD_POLL_INTERVAL:-0.5}"

# _thunderbird_desktop : le gabarit rendu sur stdout, @THUNDERBIRD_DIR@ remplacé
# par le chemin absolu d'installation (remplacement entre guillemets : un « & »
# dans le chemin reste littéral).
_thunderbird_desktop() {
  local tpl
  tpl=$(<"$DOTFILES_DIR/$THUNDERBIRD_DESKTOP_SRC") || return 1
  printf '%s\n' "${tpl//@THUNDERBIRD_DIR@/"$THUNDERBIRD_DIR"}"
}

# _thunderbird_wanted_lang : la langue de Thunderbird qui correspond à celle
# d'Ubuntu (D6). Langue d'Ubuntu : premier élément de LANGUAGE, sinon LC_ALL,
# LC_MESSAGES, LANG (ordre de gettext) ; ll_CC.codeset@mod → ll-CC s'il est
# publié, sinon ll, sinon en-US (fr_CA → fr : Mozilla ne publie pas de fr-CA).
_thunderbird_wanted_lang() {
  local raw=${LANGUAGE:-} code
  raw=${raw%%:*}
  [[ -z $raw || $raw == C || $raw == POSIX ]] && raw=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}
  raw=${raw%%.*}; raw=${raw%%@*}
  for code in "${raw/_/-}" "${raw%%_*}"; do
    [[ -n $code && " $THUNDERBIRD_LOCALES " == *" $code "* ]] && { printf '%s\n' "$code"; return 0; }
  done
  printf '%s\n' "$THUNDERBIRD_DEFAULT_LOCALE"
}

# _thunderbird_installed_lang <dossier> : langue de la version installée dans
# <dossier>, premier élément de res/multilocale.txt dans omni.ja (« fr,en-US »
# pour la version française). Rien sur stdout, et 1, si c'est illisible.
_thunderbird_installed_lang() {
  local list
  list=$(unzip -p -- "$1/omni.ja" res/multilocale.txt 2>/dev/null) || return 1
  list=${list%%,*}; list=${list//[[:space:]]/}
  [[ -n $list ]] || return 1
  printf '%s\n' "$list"
}

# --- Profil (D9) ------------------------------------------------------------------

# _thunderbird_root : dossier des profils — THUNDERBIRD_PROFILES (tests), sinon
# le dossier XDG, sauf si seul l'ancien ~/.thunderbird existe (Thunderbird garde
# alors l'emplacement historique).
_thunderbird_root() {
  if [[ -n ${THUNDERBIRD_PROFILES:-} ]]; then printf '%s\n' "$THUNDERBIRD_PROFILES"; return; fi
  local xdg=${XDG_CONFIG_HOME:-$HOME/.config}/thunderbird
  if [[ ! -f $xdg/profiles.ini && -f $HOME/.thunderbird/profiles.ini ]]; then
    printf '%s\n' "$HOME/.thunderbird"
  else
    printf '%s\n' "$xdg"
  fi
}

# _thunderbird_profile : dossier du profil que Thunderbird ouvrira, sur stdout,
# sans rien afficher d'autre (sert aussi aux sondes de module_check). Codes :
# 0 profil imprimé, 1 aucun profil, 2 plusieurs installations inscrites.
# installs.ini d'abord (une seule section, Default= absolu s'il commence par
# « / »), sinon la section de profiles.ini qui porte Default=1 (IsRelative).
_thunderbird_profile() {
  local root path sections
  root=$(_thunderbird_root)
  if [[ -f $root/installs.ini ]]; then
    sections=$(grep -c '^\[' "$root/installs.ini" 2>/dev/null) || sections=0
    (( sections > 1 )) && return 2
    path=$(sed -n 's/^Default=//p' "$root/installs.ini" | head -n 1)
    if [[ -n $path ]]; then
      [[ $path == /* ]] || path="$root/$path"
      printf '%s\n' "$path"
      return 0
    fi
  fi
  [[ -f $root/profiles.ini ]] || return 1
  path=$(awk -F= '
    function flush() { if (def == "1" && p != "") { print (rel == "0" ? "A" : "R") p; found = 1; exit } }
    /^\[/ { flush(); p = ""; rel = "1"; def = ""; next }
    $1 == "Path" { p = substr($0, 6) }
    $1 == "IsRelative" { rel = $2 }
    $1 == "Default" { def = $2 }
    END { if (!found) flush() }' "$root/profiles.ini")
  [[ -n $path ]] || return 1
  if [[ ${path:0:1} == A ]]; then printf '%s\n' "${path:1}"; else printf '%s\n' "$root/${path:1}"; fi
}

# _thunderbird_alive <pid> : vrai si le processus existe et n'est pas un zombie
# (kill -0 réussit sur un enfant mort pas encore attendu).
_thunderbird_alive() {
  local st
  [[ -r /proc/$1/stat ]] || return 1
  st=$(<"/proc/$1/stat") || return 1
  st=${st##*) }
  [[ ${st:0:1} != Z ]]
}

# _thunderbird_running <profil> : vrai si Thunderbird utilise le profil — verrou
# « …:+<pid> » dont le processus vit **et** est Thunderbird (/proc/<pid>/comm) :
# le verrou reste après un plantage, et son PID a pu être repris (D10).
_thunderbird_running() {
  local lock pid comm
  [[ -L $1/lock ]] || return 1
  lock=$(readlink -- "$1/lock") || return 1
  pid=${lock##*+}
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  _thunderbird_alive "$pid" || return 1
  comm=$(<"/proc/$pid/comm") 2>/dev/null || return 1
  [[ $comm == thunderbird* ]]
}

# _thunderbird_first_run : premier lancement sans fenêtre qui crée le profil de
# l'installation (D9). Lancé directement pour garder le PID de Thunderbird ;
# arrêté par SIGTERM, KILL au-delà du délai ; prefs.js exigé après l'arrêt.
# Rend 0 si le profil existe ensuite, 1 sinon (échec nommé).
_thunderbird_first_run() {
  local pid start profile found=0
  log_info "Thunderbird : création du profil (premier lancement sans fenêtre)."
  printf '[%s] $ %s --headless (arrière-plan)\n' "$(date +%H:%M:%S)" "$THUNDERBIRD_DIR/thunderbird" >>"$LOG_FILE"
  "$THUNDERBIRD_DIR/thunderbird" --headless >>"$LOG_FILE" 2>&1 </dev/null &
  pid=$!
  add_cleanup "kill -KILL $pid 2>/dev/null"
  start=$SECONDS
  # installs.ini exigé : Thunderbird écrit aussi un profil « …default » dans
  # profiles.ini, qui n'est pas celui de l'installation (relevé en VM).
  while (( SECONDS - start < THUNDERBIRD_START_TIMEOUT )); do
    if [[ -f $(_thunderbird_root)/installs.ini ]] && profile=$(_thunderbird_profile) && [[ -d $profile ]]; then
      found=1; break
    fi
    _thunderbird_alive "$pid" || break
    sleep "$THUNDERBIRD_POLL_INTERVAL"
  done
  kill -TERM "$pid" 2>/dev/null
  start=$SECONDS
  while _thunderbird_alive "$pid" && (( SECONDS - start < THUNDERBIRD_STOP_TIMEOUT )); do
    sleep "$THUNDERBIRD_POLL_INTERVAL"
  done
  if _thunderbird_alive "$pid"; then
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    log_error "Thunderbird ne s'est pas arrêté après la création du profil (arrêt forcé)."
    return 1
  fi
  wait "$pid" 2>/dev/null
  if (( ! found )) || ! profile=$(_thunderbird_profile) || [[ ! -f $profile/prefs.js ]]; then
    log_error "Création du profil de Thunderbird impossible (premier lancement sans fenêtre, $THUNDERBIRD_START_TIMEOUT s)."
    return 1
  fi
  log_ok "Profil de Thunderbird créé : $profile"
}

# --- Préférences (D11, D12) ----------------------------------------------------------

# _thunderbird_pref <prefs.js> <clé> : valeur brute d'une préférence (chaîne sans
# ses guillemets), dernière définition ; rien si elle manque.
_thunderbird_pref() {
  local line
  line=$(grep -F "user_pref(\"$2\", " -- "$1" 2>/dev/null | tail -n 1) || return 0
  line=${line#*\", }
  line=${line%);}
  line=${line#\"}
  printf '%s\n' "${line%\"}"
}

# _thunderbird_real_accounts <prefs.js> : comptes de mail.accountmanager.accounts
# dont le serveur n'est pas de type « none » (« Local Folders » ne compte pas).
_thunderbird_real_accounts() {
  local accounts account server
  accounts=$(_thunderbird_pref "$1" mail.accountmanager.accounts)
  for account in ${accounts//,/ }; do
    server=$(_thunderbird_pref "$1" "mail.account.$account.server")
    [[ -n $server && $(_thunderbird_pref "$1" "mail.server.$server.type") != none ]] && printf '%s\n' "$account"
  done
  return 0
}

# _thunderbird_next <prefs.js> <famille> <préfixe> : premier numéro libre (max + 1)
# des clés « <famille>.<préfixe><n>. » ; ex. mail.account account → account3.
_thunderbird_next() {
  local max=0 n
  while read -r n; do
    (( n > max )) && max=$n
  done < <(grep -oE "\"$2\\.$3[0-9]+\\." -- "$1" 2>/dev/null | grep -oE '[0-9]+')
  printf '%s\n' "$(( max + 1 ))"
}

# _thunderbird_js <valeur> : chaîne échappée pour prefs.js (\, ", saut de ligne,
# retour chariot).
_thunderbird_js() {
  local v=${1//\\/\\\\}
  v=${v//\"/\\\"}
  v=${v//$'\n'/\\n}
  printf '%s' "${v//$'\r'/\\r}"
}

# _thunderbird_account_present : le profil porte un serveur imap.gmail.com dont
# l'identifiant est une adresse du domaine de travail (D12). Sans 1Password.
_thunderbird_account_present() {
  local profile prefs server
  profile=$(_thunderbird_profile) || return 1
  prefs=$profile/prefs.js
  [[ -f $prefs ]] || return 1
  while read -r server; do
    [[ $(_thunderbird_pref "$prefs" "mail.server.$server.userName") == *@"$THUNDERBIRD_WORK_DOMAIN" ]] && return 0
  done < <(grep -oE 'user_pref\("mail\.server\.[A-Za-z0-9_]+\.hostname", "imap\.gmail\.com"\)' -- "$prefs" \
             | sed -E 's/^user_pref\("mail\.server\.([A-Za-z0-9_]+)\.hostname.*/\1/')
  return 1
}

# _thunderbird_google_connected : autorisation OAuth2 de Google dans le profil
# (D12). Rend 0 ou 1 seulement (grep rendrait 2 sur un fichier absent).
_thunderbird_google_connected() {
  local profile
  profile=$(_thunderbird_profile) || return 1
  [[ -f $profile/logins.json ]] || return 1
  grep -Fq '"hostname":"oauth://accounts.google.com"' -- "$profile/logins.json"
}

# --- Lecture de l'élément 1Password (D8) ---------------------------------------------

# _thunderbird_op <chemin> <nom attendu> : lit « <élément>/<chemin> » dans
# _TB_VALUE. Codes : 0 lu, 3 champ absent (message « does not have a field
# '<nom attendu>' »), 1 toute autre erreur. Erreurs de op versées au journal.
_TB_VALUE=""
_TB_ERR=""
_thunderbird_op() {
  _TB_VALUE=""
  if _TB_VALUE=$(op_read "$THUNDERBIRD_OP_ITEM/$1" 2>"$_TB_ERR"); then
    return 0
  fi
  cat -- "$_TB_ERR" >>"$LOG_FILE" 2>/dev/null
  grep -qF -- "$THUNDERBIRD_OP_NOT_FOUND '$2'" "$_TB_ERR" && return 3
  return 1
}

# _thunderbird_read_calendars <adresse> : lit les agendas de l'élément ; leurs
# préférences (D11) dans _TB_CAL_PREFS, leur nombre dans _TB_CAL_COUNT. Rend 1 sur
# une erreur de lecture autre que la fin de liste. Lignes mal formées : averties,
# sautées.
_TB_CAL_PREFS=""
_TB_CAL_COUNT=0
_thunderbird_read_calendars() {
  local address=$1 i rc fields name id color access view uuid order="" enc
  _TB_CAL_PREFS=""; _TB_CAL_COUNT=0
  for (( i = 1; i <= THUNDERBIRD_AGENDAS_MAX; i++ )); do
    _thunderbird_op "agendas/$i" "agendas.$i"; rc=$?
    (( rc == 3 )) && break
    (( rc == 0 )) || return 1
    IFS=';' read -r -a fields <<<"$_TB_VALUE"
    name=${fields[0]:-}; id=${fields[1]:-}; color=${fields[2]:-}; access=${fields[3]:-}; view=${fields[4]:-}
    if (( ${#fields[@]} != 5 )) || [[ -z $name || -z $id || $id == *[%/]* ]] \
       || ! [[ $color =~ ^#[0-9A-Fa-f]{6}$ ]] \
       || [[ $access != lecture && $access != ecriture ]] || [[ $view != affiche && $view != masque ]]; then
      log_warn "Thunderbird : agenda « agendas/$i » mal formé dans 1Password, sauté (attendu : nom;identifiant;#RRGGBB;lecture|ecriture;affiche|masque, identifiant sans % ni /)."
      continue
    fi
    uuid=$(</proc/sys/kernel/random/uuid)
    enc=${id//%/%25}; enc=${enc//@/%40}; enc=${enc//#/%23}
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.type\", \"caldav\");"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.uri\", \"$(_thunderbird_js "$THUNDERBIRD_CALDAV_URL/$enc/events/")\");"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.name\", \"$(_thunderbird_js "$name")\");"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.color\", \"$color\");"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.readOnly\", $([[ $access == lecture ]] && echo true || echo false));"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.username\", \"$(_thunderbird_js "$address")\");"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.cache.enabled\", true);"$'\n'
    _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.calendar-main-in-composite\", $([[ $view == affiche ]] && echo true || echo false));"$'\n'
    [[ $id == "$address" ]] && _TB_CAL_PREFS+="user_pref(\"calendar.registry.$uuid.calendar-main-default\", true);"$'\n'
    order+="${order:+ }$uuid"
    _TB_CAL_COUNT=$(( _TB_CAL_COUNT + 1 ))
  done
  [[ -n $order ]] && _TB_CAL_PREFS+="user_pref(\"calendar.list.sortOrder\", \"$order\");"$'\n'
  return 0
}

# --- Écriture du compte (D8 à D11, D13) ------------------------------------------------

# _thunderbird_manual <avertissement> <étape> : empêchement → étape manuelle, code 2.
_thunderbird_manual() {
  log_warn "$1"
  manual_step "$2"
  return 2
}

# _thunderbird_write_account : écrit le compte de travail dans le profil, une fois.
# Codes : 0 écrit, 2 étape manuelle déclarée, 1 erreur réelle (nommée). Ordre :
# empêchements sans 1Password, puis lecture de l'élément, puis profil, puis écriture.
_thunderbird_write_account() {
  local profile rc prefs name address signature tpl block tmp keys_account keys_server keys_id keys_smtp
  local accounts smtps lastkey
  # 1. Sans lire 1Password : plusieurs installations, autre compte, Thunderbird ouvert.
  profile=$(_thunderbird_profile); rc=$?
  (( rc == 2 )) && { _thunderbird_manual "Thunderbird : plusieurs installations inscrites sur le poste, profil à retenir inconnu ; compte non écrit." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return; }
  if (( rc == 0 )) && [[ -f $profile/prefs.js ]]; then
    [[ -n $(_thunderbird_real_accounts "$profile/prefs.js") ]] \
      && { _thunderbird_manual "Thunderbird : le profil porte déjà un autre compte de courriel ; le compte de travail n'est pas ajouté." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return; }
  fi
  if (( rc == 0 )) && _thunderbird_running "$profile"; then
    _thunderbird_manual "Thunderbird est ouvert : le compte de travail ne peut pas être écrit." "$THUNDERBIRD_CLOSE_MANUAL"; return
  fi
  # 2. Élément 1Password.
  op_session_active || { _thunderbird_manual "Thunderbird : aucune session 1Password, le compte ne peut pas être lu." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return; }
  _TB_ERR=$(mktemp -t dotfiles-thunderbird-op.XXXXXX) || return 1
  add_cleanup "rm -f -- '$_TB_ERR'"
  _thunderbird_op nom nom; rc=$?
  (( rc == 0 )) && name=$_TB_VALUE
  if (( rc != 0 )) || [[ -z $name ]]; then
    _thunderbird_manual "Thunderbird : nom illisible ou absent dans 1Password (« $THUNDERBIRD_OP_ITEM/nom »)." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return
  fi
  _thunderbird_op adresse adresse; rc=$?
  (( rc == 0 )) && address=$_TB_VALUE
  if (( rc != 0 )) || [[ -z $address ]]; then
    _thunderbird_manual "Thunderbird : adresse illisible ou absente dans 1Password (« $THUNDERBIRD_ADDRESS_REF »)." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return
  fi
  if [[ $address != *@"$THUNDERBIRD_WORK_DOMAIN" ]]; then
    _thunderbird_manual "Thunderbird : l'adresse de 1Password n'est pas du domaine $THUNDERBIRD_WORK_DOMAIN ; compte non écrit." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return
  fi
  _thunderbird_op notesPlain notesPlain; rc=$?
  case $rc in
    0) signature=$_TB_VALUE ;;
    3) signature="" ;;
    *) _thunderbird_manual "Thunderbird : signature illisible dans 1Password (voir le journal) ; compte non écrit." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return ;;
  esac
  _thunderbird_read_calendars "$address" \
    || { _thunderbird_manual "Thunderbird : agendas illisibles dans 1Password (voir le journal) ; compte non écrit." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return; }
  op_session_active || { _thunderbird_manual "Thunderbird : session 1Password perdue pendant la lecture ; compte non écrit." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return; }
  # 3. Profil.
  if ! profile=$(_thunderbird_profile); then
    _thunderbird_first_run || return 1
    profile=$(_thunderbird_profile) || return 1
  fi
  prefs=$profile/prefs.js
  # 4. Thunderbird a pu être ouvert pendant la lecture.
  _thunderbird_running "$profile" \
    && { _thunderbird_manual "Thunderbird est ouvert : le compte de travail ne peut pas être écrit." "$THUNDERBIRD_CLOSE_MANUAL"; return; }
  [[ -n $(_thunderbird_real_accounts "$prefs") ]] \
    && { _thunderbird_manual "Thunderbird : le profil porte déjà un autre compte de courriel ; le compte de travail n'est pas ajouté." "$THUNDERBIRD_ACCOUNTS_MANUAL"; return; }
  # 5. Rendu : clés libres, listes fusionnées, jetons, signature en dernier.
  keys_account=$(_thunderbird_next "$prefs" mail.account account)
  lastkey=$(_thunderbird_pref "$prefs" mail.account.lastKey)
  # lastKey plus grand que les comptes restants : un numéro de compte supprimé
  # n'est pas réutilisé.
  [[ $lastkey =~ ^[0-9]+$ ]] && (( lastkey >= keys_account )) && keys_account=$(( lastkey + 1 ))
  lastkey=$keys_account
  keys_account="account$keys_account"
  keys_server="server$(_thunderbird_next "$prefs" mail.server server)"
  keys_id="id$(_thunderbird_next "$prefs" mail.identity id)"
  keys_smtp="smtp$(_thunderbird_next "$prefs" mail.smtpserver smtp)"
  accounts=$(_thunderbird_pref "$prefs" mail.accountmanager.accounts)
  accounts="$keys_account${accounts:+,$accounts}"
  smtps=$(_thunderbird_pref "$prefs" mail.smtpservers)
  smtps="$keys_smtp${smtps:+,$smtps}"
  tpl=$(<"$DOTFILES_DIR/$THUNDERBIRD_ACCOUNT_SRC") || return 1
  tpl=${tpl//@ACCOUNTS@/"$accounts"}
  tpl=${tpl//@SMTPSERVERS@/"$smtps"}
  tpl=${tpl//@LASTKEY@/"$lastkey"}
  tpl=${tpl//@ACCOUNT@/"$keys_account"}
  tpl=${tpl//@SERVER@/"$keys_server"}
  tpl=${tpl//@IDENTITY@/"$keys_id"}
  tpl=${tpl//@SMTP@/"$keys_smtp"}
  tpl=${tpl//@SENT@/"$(_thunderbird_js "$THUNDERBIRD_GMAIL_SENT")"}
  tpl=${tpl//@DRAFTS@/"$(_thunderbird_js "$THUNDERBIRD_GMAIL_DRAFTS")"}
  tpl=${tpl//@ARCHIVE@/"$(_thunderbird_js "$THUNDERBIRD_GMAIL_ARCHIVE")"}
  tpl=${tpl//@TRASH@/"$(_thunderbird_js "$THUNDERBIRD_GMAIL_TRASH")"}
  tpl=${tpl//@TEMPLATES@/"$(_thunderbird_js "$THUNDERBIRD_GMAIL_TEMPLATES")"}
  tpl=${tpl//@ADRESSE_URL@/"$(_thunderbird_js "${address//@/%40}")"}
  tpl=${tpl//@ADRESSE@/"$(_thunderbird_js "$address")"}
  tpl=${tpl//@NOM@/"$(_thunderbird_js "$name")"}
  tpl=${tpl//@SIGNATURE@/"$(_thunderbird_js "$signature")"}
  block=$(grep -v '^//' <<<"$tpl")$'\n'$_TB_CAL_PREFS
  unset signature name
  # 6. Écriture atomique : copie de sauvegarde, temporaire du même dossier, mv.
  tmp=$(mktemp -- "$profile/.prefs.js.XXXXXX") || return 1
  add_cleanup "rm -f -- '$tmp'"
  chmod 600 -- "$tmp" || return 1
  { [[ -f $prefs ]] && cat -- "$prefs"; printf '\n%s' "$block"; } >"$tmp" \
    || { log_error "Écriture du compte de Thunderbird impossible : $tmp"; return 1; }
  if [[ -f $prefs ]]; then
    cp -p -- "$prefs" "$prefs.bak" || { log_error "Copie de sauvegarde impossible : $prefs.bak"; return 1; }
  fi
  mv -f -- "$tmp" "$prefs" || { log_error "Écriture du compte de Thunderbird impossible : $prefs"; return 1; }
  log_ok "Compte Google de travail écrit dans $profile ($_TB_CAL_COUNT agendas) : $address"
  _TB_CAL_PREFS=""
  return 0
}

# Déjà fait = binaire exécutable dans le dossier d'installation, dans la langue
# d'Ubuntu (D6), commande liée à ce binaire, lanceur identique au gabarit rendu
# (D4), stratégie des dictionnaires identique au dépôt (D7), compte de travail
# présent et autorisation Google dans le profil (D12, sans 1Password). La version
# n'est pas vérifiée : Thunderbird se met à jour lui-même.
module_check() {
  [[ -x $THUNDERBIRD_DIR/thunderbird ]] || return 1
  [[ $(_thunderbird_installed_lang "$THUNDERBIRD_DIR") == "$(_thunderbird_wanted_lang)" ]] || return 1
  [[ -L $THUNDERBIRD_BIN && $(readlink -- "$THUNDERBIRD_BIN") == "$THUNDERBIRD_DIR/thunderbird" ]] || return 1
  # cmp rend 2 si le lanceur manque : ramené à 1, seul code « à faire » du contrat.
  cmp -s -- <(_thunderbird_desktop) "$THUNDERBIRD_DESKTOP" || return 1
  cmp -s -- "$DOTFILES_DIR/$THUNDERBIRD_POLICIES_SRC" "$THUNDERBIRD_POLICIES" || return 1
  _thunderbird_account_present || return 1
  _thunderbird_google_connected
}

# Archive téléchargée puis extraite dans un dossier temporaire du même système
# de fichiers que la destination, renommé seulement s'il contient
# thunderbird/thunderbird : jamais de dossier d'installation à moitié écrit (D1).
# Installation dans une autre langue que celle d'Ubuntu : remplacée par la bonne,
# l'ancienne mise de côté dans le temporaire puis retirée, remise en place si
# l'échange échoue ; module_install ne touche jamais le profil (D6) : le compte
# y est écrit par module_configure (D13).
module_install() {
  local wanted installed="" reinstall=0 url
  wanted=$(_thunderbird_wanted_lang)
  if [[ -x $THUNDERBIRD_DIR/thunderbird ]]; then
    installed=$(_thunderbird_installed_lang "$THUNDERBIRD_DIR")
    if [[ $installed == "$wanted" ]]; then
      log_ok "Thunderbird déjà installé ($installed) : $THUNDERBIRD_DIR"
      return 0
    fi
    log_info "Thunderbird installé en « ${installed:-langue illisible} », Ubuntu en « $wanted » : réinstallation (profil conservé)."
    reinstall=1
  fi
  url=${THUNDERBIRD_URL//@LANG@/$wanted}
  local parent archive tmpdir stale
  parent=$(dirname -- "$THUNDERBIRD_DIR")
  mkdir -p -- "$parent" || return 1
  # Dossier temporaire laissé par une extraction interrompue sans nettoyage
  # (processus tué, coupure de courant) : ≈ 300 Mio que rien d'autre ne retire.
  for stale in "$parent"/.thunderbird.??????; do
    [[ -d $stale ]] || continue
    run rm -rf -- "$stale" || return 1
    log_info "Extraction interrompue retirée : $stale"
  done
  archive=$(mktemp -t thunderbird.XXXXXX.tar.xz) || return 1
  add_cleanup "rm -f '$archive'"
  ui_spin "Téléchargement de Thunderbird (archive de Mozilla)" \
    run curl -fsSL --retry 2 "$url" -o "$archive" \
    || { log_error "Téléchargement de Thunderbird impossible : $url"; return 1; }
  tmpdir=$(mktemp -d -- "$parent/.thunderbird.XXXXXX") || return 1
  add_cleanup "rm -rf '$tmpdir'"
  ui_spin "Extraction de Thunderbird" run tar -xJf "$archive" -C "$tmpdir" \
    || { log_error "Extraction de l'archive de Thunderbird impossible : $url"; return 1; }
  [[ -x $tmpdir/thunderbird/thunderbird ]] \
    || { log_error "Archive de Thunderbird sans thunderbird/thunderbird : $url"; return 1; }
  # Langue lue dans l'archive même : si elle n'est pas celle demandée (ou
  # illisible), module_check ne serait jamais satisfait et chaque relance
  # réinstallerait ; on échoue plutôt, en le nommant.
  installed=$(_thunderbird_installed_lang "$tmpdir/thunderbird")
  [[ $installed == "$wanted" ]] \
    || { log_error "Archive de Thunderbird en « ${installed:-langue illisible} » au lieu de « $wanted » : $url"; return 1; }
  if (( reinstall )); then
    run mv -T -- "$THUNDERBIRD_DIR" "$tmpdir/ancien" \
      || { log_error "Impossible de mettre de côté $THUNDERBIRD_DIR"; return 1; }
    if ! run mv -T -- "$tmpdir/thunderbird" "$THUNDERBIRD_DIR"; then
      run mv -T -- "$tmpdir/ancien" "$THUNDERBIRD_DIR"
      log_error "Impossible de placer Thunderbird dans $THUNDERBIRD_DIR (ancienne installation remise)"
      return 1
    fi
    log_ok "Thunderbird réinstallé en « $wanted » : $THUNDERBIRD_DIR"
    return 0
  fi
  run mv -T -- "$tmpdir/thunderbird" "$THUNDERBIRD_DIR" \
    || { log_error "Impossible de placer Thunderbird dans $THUNDERBIRD_DIR"; return 1; }
  log_ok "Thunderbird installé ($wanted) : $THUNDERBIRD_DIR"
}

# Commande, lanceur et stratégie des dictionnaires, sans réseau : c'est ce qui
# rétablit un lanceur retiré sans retélécharger Thunderbird (D4). Le lanceur est
# un fichier (pas un lien), réécrit seulement s'il diffère du gabarit rendu (D3).
# La stratégie est copiée dans /etc (D7) ; Thunderbird installe les dictionnaires
# au démarrage suivant.
# Puis le compte de travail, écrit une fois (D13) — un empêchement déclare son
# étape et arrête là, sans échec — et la connexion Google guidée : adresse
# affichée, mot de passe Google Workspace dans le presse-papiers, Thunderbird
# ouvert (une seule autorisation couvre courriel, contacts et agendas).
module_configure() {
  install_system_file "$THUNDERBIRD_POLICIES_SRC" "$THUNDERBIRD_POLICIES" || return 1
  mkdir -p -- "$(dirname -- "$THUNDERBIRD_BIN")" "$THUNDERBIRD_APPS_DIR" || return 1
  if [[ $(readlink -- "$THUNDERBIRD_BIN") != "$THUNDERBIRD_DIR/thunderbird" ]]; then
    run ln -sfn -- "$THUNDERBIRD_DIR/thunderbird" "$THUNDERBIRD_BIN" || return 1
    log_ok "Commande thunderbird : $THUNDERBIRD_BIN"
  fi
  if ! cmp -s -- <(_thunderbird_desktop) "$THUNDERBIRD_DESKTOP"; then
    _thunderbird_desktop >"$THUNDERBIRD_DESKTOP" || return 1
    log_ok "Lanceur Thunderbird : $THUNDERBIRD_DESKTOP"
    # Pour les MimeType (mailto:) ; absent, le menu trouve quand même le lanceur.
    if command -v update-desktop-database >/dev/null 2>&1; then
      run update-desktop-database "$THUNDERBIRD_APPS_DIR" \
        || log_warn "update-desktop-database a échoué : sans effet sur le lanceur."
    fi
  fi
  local rc=0
  if ! _thunderbird_account_present; then
    _thunderbird_write_account || rc=$?
    (( rc == 1 )) && return 1
    (( rc == 2 )) && return 0
  fi
  guided_login "Thunderbird (Google)" _thunderbird_google_connected "$THUNDERBIRD_LOGIN_MANUAL" \
    --user "$THUNDERBIRD_ADDRESS_REF" --secret "$THUNDERBIRD_GOOGLE_PASSWORD_REF" \
    --open open_detached "$THUNDERBIRD_DIR/thunderbird" ";" \
    -- "Thunderbird s'ouvre et affiche la connexion Google du compte ci-dessus." \
       "Mot de passe : coller (Ctrl-V), puis la double authentification si Google la demande." \
       "Autoriser Thunderbird : une seule autorisation couvre courriel, contacts et agendas."
}
