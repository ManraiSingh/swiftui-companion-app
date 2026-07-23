# Ziggy 🐶

A SwiftUI + Firebase **couple's companion app** built around one shared virtual pet. Two partners connect with a private code and raise **Ziggy** together  feeding, playing, sending photos and little love notes that sync between their phones in real time.

> Think of it as a Tamagotchi you and your partner keep alive together  every action one person takes shows up instantly on the other's screen.

---

## ✨ Features

- 🐶 **One shared pet, live-synced** — hunger, happiness, energy and a "love score" update in real time across both phones via Firestore snapshot listeners.
- 💞 **Private pairing** — partners link up with a generated "love code" or a tap-to-join invite link; all data lives under that relationship. A one-time cute **"You're Connected!"** popup celebrates the moment both partners first join, then never shows again.
- 📸 **Instants** — snap a photo (in-app camera or gallery), drag a caption anywhere on it, and send it. Ephemeral by design: a new instant replaces the old one, so images don't pile up.
- 🎨 **Doodle** — draw a sketch with PencilKit (7 pen types including fountain pen, watercolor, and crayon, a 16-color palette, and a bold adjustable brush) and it shows up live, edge-to-edge, on your partner's Home Screen widget.
- 💌 **One-tap love notes** — quick emotion messages (Miss You, Good Night, Hug…) that reorder by how often you use them, plus a **custom note composer with an emotion picker** that sets the exact Ziggy face your partner sees.
- 🎭 **Emotional Ziggy** — the mascot's expression reflects mood, incoming messages, and pending instants. Rename Ziggy in Settings and the name propagates everywhere — header, activity feed (past **and** future memories), notifications, widget.
- ❓ **Daily questions** — a shared question each day from a bank of 200+, so it doesn't repeat for over six months; answers reveal once both partners respond.
- 🎮 **Mini-games** — **Trace Together**, a live collaborative two-player drawing game across nine shapes, and **Tic Tac Toe**, a real-time networked match with server-validated moves — both with a shared lobby/ready-up flow and a love-score reward on completion.
- 🕰️ **Activity timeline** — "Our Memories," a shared, live-synced log of everything **both** partners have done, styled as mirrored chat bubbles.
- 🔔 **Push + local notifications** — real alerts (Cloud Functions + APNs) when your partner feeds, plays, sends a note, an Instant, a Doodle, or invites you to a game — plus local reminders when Ziggy needs attention.
- 🧩 **Home Screen widget** (WidgetKit) showing Ziggy's current state, your partner's latest message, or their live Doodle.
- ⭐ **Cute rating prompt** — after a genuinely happy milestone, a custom in-app ask offers to open Apple's native App Store review sheet.
- 🗑️ **Privacy-first** — in-app data deletion that wipes the relationship's data from the server.

---

## 🛠️ Tech Stack

| Area | Tech |
|------|------|
| UI | SwiftUI |
| Realtime backend | Firebase Firestore (snapshot listeners + transactions) |
| Push notifications | Firebase Cloud Functions (TypeScript) + APNs |
| Analytics | Firebase Analytics |
| Widget | WidgetKit + App Groups |
| Drawing | PencilKit (Doodle, Trace Together) |
| Media | PhotosUI, UIImagePickerController (camera) |
| Notifications | UserNotifications (local + remote) |
| Persistence | UserDefaults + local cache |
| Architecture | MVVM with shared service singletons |

---

## 🧱 Architecture

State flows through an observable `PetViewModel`, with focused service singletons handling each concern:

```
Views (SwiftUI)
   │  observe
   ▼
PetViewModel  ──────────────┐
   │                        │
   ├─ FirestoreManager      │  realtime sync, emotions, instants, games
   ├─ RelationshipManager   │  pairing / love code
   ├─ PersistenceManager    │  local pet cache
   ├─ WidgetDataManager     │  shared App Group store
   ├─ NotificationManager   │  local reminders
   └─ DailyQuestionManager  │  daily prompts
```

### Project structure

```
Ziggy/
├─ Models/         Pet, Event, UserManager
├─ Services/       PetViewModel + Firestore/Relationship/Persistence/Widget/Notification/DailyQuestion managers
├─ Views/          Onboarding, RelationshipSetup, Home (ContentView), Feed, Instant, Activity, Settings, Trace Together
├─ Ziggy/          App entry point, assets, Firebase config, Doodle (PencilKit), Tic Tac Toe
├─ ZiggyWidget/    Home Screen widget extension
└─ functions/      Firebase Cloud Functions (TypeScript) — partner push notifications
```

---

## 🚀 Getting Started

### Requirements
- Xcode 16+
- iOS 17+ device or simulator
- A Firebase project (free Spark plan works for development)



## 🗺️ Roadmap

- [ ] Harden Firestore join rules for the device-recovery edge case (re-pairing after losing local auth state)
- [ ] App Check
- [ ] Move Instant/Doodle images to Firebase Storage (currently base64 in Firestore docs)
- [ ] iPad-native layout (currently iPhone-only)

---


