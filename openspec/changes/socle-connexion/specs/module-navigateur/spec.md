## MODIFIED Requirements

### Requirement: Brave Sync guidé
Lorsque Brave est installé et qu'aucune chaîne de synchronisation n'est rejointe, `module_configure` SHALL proposer de rejoindre la chaîne enregistrée dans 1Password : lecture de la graine (24 mots, référence `op://Imarcom/Brave Sync Code/notesPlain`, les 24 premiers mots retenus) par le helper de lecture des secrets, calcul du 25ᵉ mot valable ce jour (nombre de jours écoulés depuis le 10 mai 2022 à 00:00 UTC, arrondi, modulo 2048, index dans la liste de mots BIP39 anglaise versionnée), copie de la phrase de 25 mots dans le presse-papiers, ouverture de Brave sans son assistant de premier lancement, avec la consigne pour atteindre la page de synchronisation (les URL `brave://` en ligne de commande sont ignorées par le navigateur), puis attente jusqu'à ce que la chaîne soit rejointe (constaté dans le profil de Brave) ou que l'utilisateur choisisse de passer. La phrase MUST NOT apparaître à l'écran ni dans le journal ; le presse-papiers SHALL être vidé à la fin du parcours dans tous les cas : chaîne rejointe, étape passée ou script interrompu. Le parcours SHALL passer par le helper de connexion guidée du socle. Sans session 1Password ou sans item dans le coffre, le module SHALL avertir, déclarer l'étape manuelle et continuer sans erreur. Si Brave a déjà rejoint une chaîne, rien n'est proposé.

#### Scenario: Chaîne rejointe
- **WHEN** Brave vient d'être installé, une session 1Password est active et l'utilisateur colle le code dans Brave puis confirme
- **THEN** le module constate la chaîne dans le profil, vide le presse-papiers et poursuit sans étape manuelle

#### Scenario: Vingt-cinquième mot
- **WHEN** le module calcule le 25ᵉ mot à une date donnée
- **THEN** le mot est celui affiché pour cette date par Brave pour la même graine (index = jours arrondis depuis le 10 mai 2022 modulo 2048 dans la liste BIP39)

#### Scenario: Passer
- **WHEN** l'utilisateur choisit de passer l'étape
- **THEN** le presse-papiers est vidé, le module continue sans erreur et le résumé final liste « Brave Sync : rejoindre la chaîne » comme étape manuelle

#### Scenario: Interruption
- **WHEN** l'utilisateur interrompt le script pendant l'attente de la chaîne
- **THEN** le presse-papiers est vidé

#### Scenario: Déjà synchronisé
- **WHEN** le profil de Brave montre une chaîne déjà rejointe
- **THEN** aucune lecture dans 1Password n'a lieu et aucune fenêtre n'est ouverte

#### Scenario: Sans session 1Password
- **WHEN** aucune session `op` n'est active
- **THEN** le module avertit, déclare l'étape manuelle et se termine sans erreur
