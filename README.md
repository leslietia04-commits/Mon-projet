# Digitalyx Exhibitor

Prototype Flutter pour la gestion des contacts exposants, utilisable hors ligne.

## Fonctionnalités disponibles

- Écran d’entrée Digitalyx Exhibitor et page d’inscription (nom complet, e-mail, entreprise, poste, téléphone, mot de passe masqué de 8 caractères minimum et confirmation), avec validation des champs et correspondance des mots de passe.
- Après inscription, accueil personnalisé par nom complet et retour à la connexion avec l’e-mail prérempli.
- Connexion visuelle avec mot de passe masqué, « Remember me » et récupération de mot de passe.
- Ouverture explicite en session de démonstration après saisie : les identifiants ne sont pas vérifiés et aucun compte n’est créé sans le service d’authentification.
- Tableau de bord exposant et navigation mobile.
- Événements et numéros de stand conservés localement.
- Création d’un événement autonome et rapprochement local par nom, ville et dates.
- Saisie d’un prospect (nom, entreprise, e-mail et téléphone obligatoires), poste, commercial responsable, qualification Chaud/Tiède/Info, tags et note.
- Lecture de QR codes de badges en formats JSON, query-string ou lignes `nom:valeur`.
- Annuaire B2B de démonstration avec recherche, filtre par secteur et fiches.
- Statistiques locales par niveau de priorité et export CSV copiable dans Excel/CRM.
- Base SQLite locale sur Android et iOS, avec migration des données existantes.

## Limites du prototype

Les profils de l’annuaire sont des exemples et ne représentent pas un catalogue
officiel. Ce projet ne dispose pas encore de serveur : comptes et liens magiques,
abonnement Pro annuel, paiements/pass selon la taille de l’équipe, codes
organisateur, annuaire privé, rapprochement avec un événement maître,
synchronisation arrière-plan, pass e-mail/SMS et envoi du kit média ne sont pas
actifs. Les statistiques, prospects, événements et le CSV portent uniquement sur
les données locales. Les notes vocales et l’export fichier Excel ne sont pas encore
implémentés. « Remember me » est visuel uniquement et la récupération du mot de
passe n’envoie aucun e-mail tant que l’authentification serveur n’est pas configurée.

## Lancer

```powershell
flutter pub get
flutter run
```

Autoriser l’accès à la caméra pour scanner un badge.
