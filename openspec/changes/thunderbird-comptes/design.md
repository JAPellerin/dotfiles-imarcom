## Context

Voir `proposal.md`. État actuel (`modules/62-thunderbird.sh`, archivé le 24 sept 2026) : archive de Mozilla dans `~/.local/share/thunderbird`, langue d'Ubuntu, commande, lanceur, stratégie des dictionnaires ; `module_install` déclare `THUNDERBIRD_ACCOUNTS_MANUAL` après une installation fraîche ; le profil n'est jamais touché. Socle : `guided_login` / `open_detached` (`lib/connexion.sh`) et la convention D5 de `openspec/changes/archive/2026-09-24-socle-connexion/design.md`.

Relevés :

| Source | Constat |
|---|---|
| VM, 24 sept 2026 (change `thunderbird`) | Thunderbird 156.0.1 ; profil dans **`~/.config/thunderbird`** (pas `~/.thunderbird`) |
| Profil Windows de l'utilisateur (`…/Profiles/sh94h20l.default-release/prefs.js`, 156.0.1, 25 sept 2026) | `mail.accountmanager.accounts = account1,account2` (account2 = « Local Folders », créé par Thunderbird) ; `mail.server.server3` : `imap`, `imap.gmail.com:993`, `socketType 3`, `is_gmail`, `login_at_startup`, `trash_folder_name "[Gmail]/Trash"`, `userName` = adresse ; `mail.smtpserver.smtp1` : `smtp.gmail.com:587`, `try_ssl 2`, `authMethod 3` (mot de passe d'application) ; `mail.identity.id1` : `fullName`, `useremail`, `reply_on_top 1`, `htmlSigFormat false`, `htmlSigText` (texte de 11 lignes, aucune balise), `attach_signature false`, `fcc_folder` / `draft_folder` / `archive_folder` en `imap://<adresse %40>@imap.gmail.com/[Gmail]/…` avec `*_picker_mode "1"`, `stationery_folder …/Templates` ; `calendar.registry.<uuid>.{type caldav, uri https://apidata.googleusercontent.com/caldav/v2/<identifiant %40>/events/, name, color, readOnly, username = adresse, cache.enabled true, calendar-main-in-composite}` pour 9 agendas, plus « Home » (`storage`) |
| `logins.json` du même profil | trois entrées : `imap://imap.gmail.com`, `smtp://smtp.gmail.com` (mot de passe d'application) et **`oauth://accounts.google.com`** ; identifiants chiffrés (lisibles seulement par NSS) |
| Préférences Mozilla | `prefs.js` est relu au démarrage et réécrit par Thunderbird en cours de route et à la fermeture : on ne l'écrit que Thunderbird fermé ; `user.js` serait réappliqué à chaque démarrage (écarté, décision de l'utilisateur) |
| Méthode d'authentification OAuth2 | `authMethod 10` (IMAP et SMTP) ; le fournisseur OAuth2 est déduit du nom d'hôte par Thunderbird (Google) — aucune préférence de portée à écrire, à confirmer en VM |

## Goals / Non-Goals

**Goals :** au premier passage, Thunderbird s'ouvre sur le compte de travail, les agendas en place, et la seule chose que fait l'utilisateur est la connexion Google (mot de passe collé, double authentification) ; aucune donnée personnelle dans le dépôt ; le profil n'est jamais écrit Thunderbird ouvert ni par-dessus un compte existant.

**Non-Goals :** fusion avec un compte existant ; tenir compte et agendas à jour après coup (écrits une fois) ; vérifier *quel* compte Google a été autorisé (identifiants chiffrés).

## Decisions

### D1. Élément `op://Imarcom/Thunderbird`
Créé par l'utilisateur (tâche 0.1), type Note sécurisée ou Login indifférent :
- champ `nom` — nom affiché (`fullName`) ;
- champ `adresse` — adresse de travail (`…@imarcom.net`), affichée par le parcours ;
- **note** (`notesPlain`) — la signature **en HTML**, logo compris (image PNG en `data:` dans la balise `<img>`) : 1Password n'a pas d'autre champ multiligne, et l'élément reste la seule source (rien dans le dépôt) ;
- section `agendas`, un champ texte par agenda nommé `1`, `2`, … — `<nom>;<identifiant Google>;<couleur #RRGGBB>;<lecture|ecriture>;<affiche|masque>`, ex. `Équipe;c_0123abcd@group.calendar.google.com;#C2C2C2;ecriture;affiche` (identifiant fictif). L'URI se déduit de l'identifiant (`@` → `%40`).
Écart avec la structure esquissée le 25 sept 2026 (agendas dans la note) : la signature occupe la seule zone multiligne de 1Password ; les agendas, une ligne chacun, vont donc en champs.
Signature (décision de l'utilisateur, 25 sept 2026) : pas celle du `prefs.js` actuel (un essai, texte brut), mais celle de ses courriels envoyés — reconstituée depuis son dernier envoi à un client (`[Gmail]/Sent Mail`, 24 sept 2026) : `--`, nom, titre, deux téléphones en liens `tel:`, logo Imarcom (PNG 178 × 36, 4,4 Ko), adresse en lien Google Maps, Helvetica 9 pt ; classes Outlook/Gmail du courriel retirées. Environ 6,6 Ko dans la note. Lus par `op_read` (`op://Imarcom/Thunderbird/nom`, `…/adresse`, `…/notesPlain`, `…/agendas/1`, `…/agendas/2`, … jusqu'au premier champ absent, 50 au plus) ; erreurs de `op` vers le journal. Signature absente → aucune signature ; aucun agenda → compte seul. Nom ou adresse absents → étape manuelle (spec). Ligne d'agenda mal formée (pas 5 champs, couleur invalide, mot-clé inconnu) → avertissement qui nomme le champ, agenda sauté.
Mot de passe Google Workspace de travail : `THUNDERBIRD_GOOGLE_PASSWORD_REF="op://Imarcom/Google Workspace/password"` (élément existant, nommé par l'utilisateur le 25 sept 2026 ; son `username` est l'adresse de travail). La référence contient une espace : toujours citée.

### D2. Profil : trouver, créer
Racine `THUNDERBIRD_PROFILES="${THUNDERBIRD_PROFILES:-$HOME/.config/thunderbird}"`. `_thunderbird_profile` imprime le dossier du profil que Thunderbird ouvrira : `Default=` de la section d'installation de `installs.ini` s'il y en a une, sinon la section de `profiles.ini` qui porte `Default=1` (chemin relatif si `IsRelative=1`) ; rien s'il n'y en a pas.
Aucun profil (Thunderbird jamais lancé) → `run "$THUNDERBIRD_DIR/thunderbird" --headless -CreateProfile default-release` (option documentée de Mozilla, qui crée et inscrit le profil puis rend la main sans fenêtre), puis `Default=1` sur ce profil dans `profiles.ini` s'il manque. **À vérifier en VM (tâche 0.2)** : qu'au premier lancement normal, Thunderbird adopte ce profil (installation « dédiée » : Thunderbird prend le profil par défaut qu'aucune autre installation ne réclame) au lieu d'en créer un second. Repli si ce n'est pas le cas : premier lancement de Thunderbird par le module en `--headless`, arrêté dès que `installs.ini` désigne un profil — D2 est alors corrigé.

### D3. Thunderbird fermé
`_thunderbird_running <profil>` : vrai si `<profil>/lock` est un lien symbolique dont le PID (`…:+<pid>`) est vivant (`kill -0`) — le verrou reste après un plantage, le PID tranche. Ouvert → `ui_choose "Thunderbird est ouvert : le fermer, puis…" "Continuer" "Passer (étape manuelle)"` ; toujours ouvert après « Continuer » → étape manuelle (pas de boucle), comme « Passer ».

### D4. Écriture unique du compte
`config/thunderbird/compte.js` : gabarit des `user_pref(…)` du compte, **sans donnée personnelle**, jetons `@ADRESSE@`, `@ADRESSE_URL@` (`@` → `%40`), `@NOM@`, `@SIGNATURE@` — commentaire d'en-tête sans jeton en toutes lettres (leçon du lanceur, change `thunderbird`). Contenu, repris de l'actuel : `mail.accountmanager.accounts "account1"`, `defaultaccount`, `mail.account.account1.{identities id1, server server1}`, `mail.account.lastKey 1` ; `mail.server.server1` (`imap`, `imap.gmail.com`, 993, `socketType 3`, **`authMethod 10`**, `userName`, `name`, `is_gmail`, `login_at_startup`, `check_new_mail`, `trash_folder_name`) ; `mail.smtpservers "smtp1"`, `mail.smtp.defaultserver`, `mail.smtpserver.smtp1` (`smtp.gmail.com`, 587, `try_ssl 2`, **`authMethod 10`**, `username`, `type smtp`) ; `mail.identity.id1` (`fullName`, `useremail`, `smtpServer`, `valid`, `reply_on_top 1`, **`htmlSigFormat true`** (signature HTML, D1 ; l'actuel est en texte), `htmlSigText`, `attach_signature false`, dossiers `fcc`/`draft`/`archive`/`stationery` et `*_picker_mode` comme l'actuel). « Local Folders » n'est pas écrit : Thunderbird le crée au démarrage (à confirmer en VM).
Agendas : un bloc par ligne valide, `calendar.registry.<uuid>.{type caldav, uri, name, color, readOnly, username @ADRESSE@, cache.enabled true, calendar-main-in-composite}` ; UUID de `/proc/sys/kernel/random/uuid`. « Home » n'est pas écrit (Thunderbird le crée).
Chaînes échappées pour JavaScript (`\` → `\\`, `"` → `\"`, saut de ligne → `\n`) par une fonction dédiée. Remplacement des jetons entre guillemets dans l'expansion (`${tpl//@NOM@/"$nom"}`), comme `_thunderbird_desktop`.
Écriture : profil déjà porteur d'un compte (`mail.accountmanager.accounts` non vide dans `prefs.js`) → rien, étape manuelle (spec : pas de fusion). Sinon `prefs.js` copié en `prefs.js.bak` s'il existe, bloc rendu **ajouté** à `prefs.js` (créé 0600 s'il manque) ; Thunderbird l'absorbe au démarrage et le réécrit à sa façon. Nom, signature et agendas ne sont jamais journalisés ; l'adresse l'est (affichée par le parcours de toute façon). Journal : « Compte Google de travail écrit dans <profil> (N agendas) ».

### D5. Sondes et `module_check`
- `_thunderbird_account_present` : le profil existe et son `prefs.js` porte `user_pref("mail.server.server<n>.hostname", "imap.gmail.com")` (`grep -Eq` sur le fichier). Ne dépend pas de l'adresse (qui est dans 1Password) : un compte Gmail quelconque compte ; c'est aussi la règle « pas de fusion » (D4) vue de l'autre côté.
- `_thunderbird_google_connected` : `logins.json` du profil contient `"hostname":"oauth://accounts.google.com"` (`grep -Fq`, espaces tolérés par `-E` au besoin). **À vérifier en VM** : que Thunderbird l'écrit dès l'autorisation, sans attendre la fermeture.
`module_check` : conditions actuelles, puis les deux sondes.

### D6. Déroulé de `module_configure`
Étapes actuelles (stratégie, commande, lanceur), puis :
1. `_thunderbird_account_present` faux → `_thunderbird_write_account` (D1 à D4) : 0 écrit, 2 étape manuelle déclarée (arrêt du parcours, retour 0 du module), 1 erreur réelle (profil impossible à créer, écriture en échec → le module échoue en le nommant).
2. `guided_login "Thunderbird (Google)" _thunderbird_google_connected "$THUNDERBIRD_ACCOUNTS_MANUAL" --user "$THUNDERBIRD_ADDRESS_REF" (`op://Imarcom/Thunderbird/adresse`) --secret "$THUNDERBIRD_GOOGLE_PASSWORD_REF" --open open_detached "$THUNDERBIRD_DIR/thunderbird" ";" -- "Thunderbird s'ouvre et affiche la connexion Google du compte ci-dessus." "Mot de passe : coller (Ctrl-V), puis la double authentification si Google la demande." "Autoriser Thunderbird (courriel, agendas, contacts)."` — consignes ajustées après la VM (une seule autorisation pour courriel et agendas, ou deux).
`module_install` ne déclare plus `THUNDERBIRD_ACCOUNTS_MANUAL` (texte conservé pour le repli, reformulé : « Ouvrir Thunderbird et ajouter le compte Google de travail et les agendas »). `MODULE_DESC` complété (« ; compte Google et agendas depuis 1Password »).

### D7. Tests (`tests/test-thunderbird.sh`)
Doublures : `thunderbird` factice qui répond à `--headless -CreateProfile <nom>` en créant le dossier et `profiles.ini` ; `op` (session ; champs `nom`, `adresse`, `notesPlain` en HTML avec `"`, `\`, sauts de ligne et une image `data:`, `agendas/1..3` dont une ligne mal formée, mot de passe ; échec sur demande) ; `wl-copy`, `ui_choose`, `setsid` comme `test-connexion.sh` ; délais courts. Cas : aucun profil → profil créé, `Default=1`, bloc écrit (comptes, `authMethod 10` ×2, identité, signature correctement échappée — `prefs.js` relu par un petit analyseur `user_pref` du test —, 2 agendas, ligne mal formée sautée avec avertissement), parcours lancé ; profil existant sans compte → `prefs.js.bak`, bloc ajouté ; compte présent → aucun `op` pour le compte, `prefs.js` intact ; autre compte présent → étape, `prefs.js` intact ; Thunderbird ouvert (verrou + PID vivant) puis « Passer » → étape, intact ; verrou orphelin (PID mort) → écrit ; sans session → étape, retour 0, aucun parcours ; nom manquant → étape ; `_thunderbird_google_connected` (entrée présente / absente / pas de `logins.json`) ; `module_check` sur chaque condition ; mot de passe **et** signature absents de la sortie et du journal ; installation fraîche → plus d'étape déclarée par `module_install`. Cas existants adaptés.

## Risks / Trade-offs

- [`-CreateProfile` et profil « dédié »] → tâche 0.2 avant le code ; repli décrit en D2.
- [Préférences écrites différemment dans une version future de Thunderbird (ex. serveurs sortants renommés)] → le gabarit reprend un profil 156 réel ; Thunderbird migre ses propres préférences au démarrage ; validé en VM.
- [Autorisation OAuth2 d'un autre compte Google] → invisible pour la sonde (identifiants chiffrés) ; la consigne affiche l'adresse attendue.
- [Écrasement d'un `prefs.js` modifié entre la lecture et l'ajout] → impossible Thunderbird fermé (D3) ; `prefs.js.bak` en filet.
- [Logo en `data:` dans la signature] → Thunderbird l'envoie comme image intégrée ; **à vérifier en VM** (courriel de test : logo visible chez le destinataire, pas de pièce jointe séparée). Repli : `sig_file` vers un fichier HTML et une image dans le profil, écrits par le module depuis la note.
- [Adresses de collègues] → seulement dans 1Password et dans le profil de l'utilisateur ; jamais au journal ni dans le dépôt.

## Migration Plan

Poste où le compte existe déjà : `module_check` le constate, seule la connexion est vérifiée. Retour arrière d'un premier passage : `prefs.js.bak` du profil, ou supprimer `~/.config/thunderbird` avant tout usage ; revenir au commit précédent.
