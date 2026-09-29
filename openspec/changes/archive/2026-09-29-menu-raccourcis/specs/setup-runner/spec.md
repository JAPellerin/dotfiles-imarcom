## MODIFIED Requirements

### Requirement: Menu interactif par défaut
Sans argument, le runner SHALL afficher un menu à sélection multiple listant tous les modules découverts, chacun sous la forme `[groupe] nom — description — état`, puis exécuter la sélection. Les modules pas encore faits SHALL être présélectionnés ; les modules déjà faits SHALL être présentés mais non présélectionnés. Ainsi, valider le menu sans rien changer installe tout ce qui manque. Le menu SHALL annoncer, dans son en-tête, les gestes pour cocher ou décocher un module, pour tout cocher ou tout décocher d'un coup, et pour lancer la sélection.

#### Scenario: Machine vierge
- **WHEN** l'utilisateur lance `setup.sh` sur une machine où aucun module n'est fait et valide le menu sans rien changer
- **THEN** tous les modules disponibles dans cet environnement s'exécutent, dans l'ordre de leurs dépendances

#### Scenario: Sélection ajustée
- **WHEN** l'utilisateur lance `setup.sh` sans argument, décoche tout sauf `base` et `1password`
- **THEN** seuls ces deux modules s'exécutent, dans l'ordre de leurs dépendances

#### Scenario: État visible
- **WHEN** le module `base` a déjà été appliqué sur la machine
- **THEN** le menu l'affiche sous `[systeme] base` avec un marqueur « déjà fait » et il n'est pas présélectionné

#### Scenario: Tout décocher
- **WHEN** l'utilisateur ouvre le menu et suit l'en-tête pour tout décocher, puis coche un seul module
- **THEN** seul ce module (et ses dépendances) s'exécute
