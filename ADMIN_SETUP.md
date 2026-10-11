# OrthoOrganizer account approval

Οι εγγραφές είναι ανοικτές, αλλά κάθε νέος λογαριασμός δημιουργείται ως `pending`. Δεν υπάρχει κωδικός πρόσκλησης. Ο χρήστης δεν βλέπει αρχεία και δεν μπορεί να συγχρονίσει μέχρι να εγκριθεί.

## Πρώτη ενεργοποίηση διαχειριστή

1. Άνοιξε το Firebase Console → Firestore Database.
2. Δημιούργησε/εντόπισε τον χρήστη σου στο Authentication και κράτησε το UID.
3. Δημιούργησε το document `users/{UID}/access/profile` με:

   - `username` (string)
   - `email` (string)
   - `status` (string): `active`
   - `role` (string): `admin`
   - `sessionVersion` (number): `1`
   - `deviceCount` (number): `0`

4. Δημιούργησε το document `adminControl/managedUsers/{UID}` με τα ίδια πεδία.
5. Δημιούργησε το document `adminControl/policy` με:

   - `registrationOpen` (boolean): `true`
   - `approvalRequired` (boolean): `true`
   - `maximumActiveUsers` (number): `10`
   - `maximumDevicesPerUser` (number): `2`
   - `minimumAppVersion` (string): `0.6.6`
   - `activeUserCount` (number): `1`

Μετά το πρώτο login εμφανίζεται στις ρυθμίσεις η «Διαχείριση χρηστών». Από εκεί γίνεται έγκριση, αναστολή, ανάκληση συνδέσεων, κλείσιμο εγγραφών και αλλαγή ορίων.

## Firestore Rules

Το αρχείο `firebase/firestore.rules` είναι η αντίστοιχη πολιτική πρόσβασης. Εφάρμοσέ το από το Firebase Console ή με Firebase CLI, αφού ελέγξεις ότι τα υπάρχοντα production paths συμφωνούν με αυτά του project.

Ο κώδικας των εφαρμογών δεν βασίζεται σε πρόσκληση. Η τελική προστασία γίνεται server-side από τα access documents και τους κανόνες Firestore.
