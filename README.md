# ProgrammingTriviaBattle

**ProgrammingTriviaBattle** je Flutter aplikacija za kvize, ki omogoča tako **solo** kot **multiplayer** igro.  
Projekt uporablja **Firebase** za avtentikacijo, shranjevanje rezultatov in real-time multiplayer igre. Vprašanja za kviz pridobiva iz **Open Trivia Database (OpenTDB)** API-ja.

---

## Funkcionalnosti

### Solo način igre
- Avtomatska generacija vprašanj iz različnih kategorij
- 4 možnosti odgovora
- Avtomatsko štetje točk
- Rezultati shranjeni v Firestore

### Multiplayer način
- **Ustvarjanje lobbyja**:
  - Izbira imena lobbyja
  - Izbira števila igralcev (2-8)
  - Avtomatska dodelitev host vloge
- **Pridružitev lobbyju**:
  - Pregled vseh dostopnih lobbyjev
  - Avtomatska pridobitev podatkov iz Firestore
- **Ready sistem**:
  - Vsak igralec se mora pripraviti pred začetkom
  - Host lahko začne igro samo ko so vsi igralci ready
- **Real-time multiplayer igra**:
  - Vsi igralci vidijo isto vprašanje hkrati
  - 10-sekundni čas za odgovor
  - Samodejno prehajanje na naslednje vprašanje
  - Realtime prikaz točk
- **Konec igre**:
  - Prikaz končnih rezultatov
  - Avtomatsko shranjevanje statistike
  - Prepoznavanje zmagovalca/izenačenja

### Statistika in lestvica
- **Personalna statistika**:
  - Skupne točke
  - Najboljši rezultat
  - Natančnost odgovorov
  - Pravilni odgovori
  - Multiplayer statistika (zmage/porazi)
- **Globalna lestvica**:
  - Top 3 igralci s posebno vizualizacijo
  - Seznam vseh igralcev po točkah
  - Osvetlitev trenutnega uporabnika
  - Prikaz števila iger

### Firebase integracija
- Avtentikacija uporabnikov
- Shranjevanje rezultatov solo in multiplayer iger
- Real-time Firestore posodobitve za multiplayer
- Avtomatsko ustvarjanje uporabniškega profila

### Druge funkcionalnosti
- Dekodiranje HTML entitet v vprašanjih (npr. `&quot;` → `"`)
- Preverjanje internetne povezave pred začetkom igre
- Responsiven UI za različne velikosti zaslona
- Intuitiven uporabniški vmesnik

---

## Zahteve

### Tehnologije
- Flutter SDK ≥ 3.0.0
- Dart ≥ 3.0.0
- Firebase projekt z omogočenimi:
  - Firestore Database
  - Firebase Authentication
  - Firebase Cloud Functions (priporočljivo za multiplayer logiko)

### Povezave
- Internetna povezava za pridobivanje vprašanj iz OpenTDB
- Firebase povezava za avtentikacijo in shranjevanje podatkov

---

## Namestitev

### 1. Kloniraj repozitorij

git clone https://github.com/tvoje-uporabnisko-ime/triviabattle.git
cd triviabattle

### 2. Namesti odvisnosti

flutter pub get

### 3. Poveži Firebase projekt

1. **Ustvari Firebase projekt**
   - Obišči [Firebase Console](https://console.firebase.google.com/)
   - Ustvari nov projekt

2. **Dodaj Android aplikacijo**
   - Paket ime: `com.example.prog_trivia_battle` (primer)
   - Prenesi datoteko `google-services.json`
   - Postavi datoteko v mapo: `android/app/`

3. **Omogoči Firestore in Firebase Authentication**

- V Firebase konzoli omogoči Firestore Database.
- Omogoči Firebase Authentication.


### 4. Zaženi aplikacijo

- flutter pub run flutter_launcher_icons:main
- flutter clean
- flutter pub get
- flutter run

