// Compte Google de travail de Thunderbird — gabarit rendu par le module
// `thunderbird` et ajouté une seule fois au prefs.js du profil, Thunderbird fermé.
// Aucune donnée personnelle ici : adresse, nom et signature viennent de
// 1Password ; les agendas sont ajoutés par le module. Les jetons (un mot en
// majuscules entre deux arobases) sont remplacés au rendu ; ce commentaire n'en
// contient aucun, il serait remplacé aussi. Les numéros de compte, de serveur,
// d'identité et de serveur sortant sont les premiers libres du profil.
// Préférences reprises du profil Thunderbird 156 de l'utilisateur et du compte
// ajouté par l'assistant en VM (25 sept 2026), en OAuth2 (authMethod 10).
// Voir openspec/changes/thunderbird-comptes/design.md (D11).
user_pref("mail.accountmanager.accounts", "@ACCOUNTS@");
user_pref("mail.accountmanager.defaultaccount", "@ACCOUNT@");
user_pref("mail.account.lastKey", @LASTKEY@);
user_pref("mail.account.@ACCOUNT@.identities", "@IDENTITY@");
user_pref("mail.account.@ACCOUNT@.server", "@SERVER@");
user_pref("mail.server.@SERVER@.type", "imap");
user_pref("mail.server.@SERVER@.hostname", "imap.gmail.com");
user_pref("mail.server.@SERVER@.port", 993);
user_pref("mail.server.@SERVER@.socketType", 3);
user_pref("mail.server.@SERVER@.authMethod", 10);
user_pref("mail.server.@SERVER@.userName", "@ADRESSE@");
user_pref("mail.server.@SERVER@.name", "@ADRESSE@");
user_pref("mail.server.@SERVER@.is_gmail", true);
user_pref("mail.server.@SERVER@.login_at_startup", true);
user_pref("mail.server.@SERVER@.check_new_mail", true);
user_pref("mail.server.@SERVER@.trash_folder_name", "@TRASH@");
user_pref("mail.smtpservers", "@SMTPSERVERS@");
user_pref("mail.smtp.defaultserver", "@SMTP@");
user_pref("mail.smtpserver.@SMTP@.type", "smtp");
user_pref("mail.smtpserver.@SMTP@.hostname", "smtp.gmail.com");
user_pref("mail.smtpserver.@SMTP@.port", 587);
user_pref("mail.smtpserver.@SMTP@.try_ssl", 2);
user_pref("mail.smtpserver.@SMTP@.authMethod", 10);
user_pref("mail.smtpserver.@SMTP@.username", "@ADRESSE@");
user_pref("mail.shell.checkDefaultClient", false);
user_pref("mail.identity.@IDENTITY@.fullName", "@NOM@");
user_pref("mail.identity.@IDENTITY@.useremail", "@ADRESSE@");
user_pref("mail.identity.@IDENTITY@.smtpServer", "@SMTP@");
user_pref("mail.identity.@IDENTITY@.valid", true);
user_pref("mail.identity.@IDENTITY@.reply_on_top", 1);
user_pref("mail.identity.@IDENTITY@.sig_bottom", false);
user_pref("mail.identity.@IDENTITY@.htmlSigFormat", true);
user_pref("mail.identity.@IDENTITY@.attach_signature", false);
user_pref("mail.identity.@IDENTITY@.fcc_folder", "imap://@ADRESSE_URL@@imap.gmail.com/@SENT@");
user_pref("mail.identity.@IDENTITY@.fcc_folder_picker_mode", "1");
user_pref("mail.identity.@IDENTITY@.draft_folder", "imap://@ADRESSE_URL@@imap.gmail.com/@DRAFTS@");
user_pref("mail.identity.@IDENTITY@.drafts_folder_picker_mode", "1");
user_pref("mail.identity.@IDENTITY@.archive_folder", "imap://@ADRESSE_URL@@imap.gmail.com/@ARCHIVE@");
user_pref("mail.identity.@IDENTITY@.archives_folder_picker_mode", "1");
user_pref("mail.identity.@IDENTITY@.stationery_folder", "imap://@ADRESSE_URL@@imap.gmail.com/@TEMPLATES@");
user_pref("mail.identity.@IDENTITY@.tmpl_folder_picker_mode", "0");
user_pref("mail.identity.@IDENTITY@.htmlSigText", "@SIGNATURE@");
