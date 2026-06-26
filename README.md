# Ziggy 🐶

A SwiftUI + Firebase **couple's companion app** built around one shared virtual pet. Two partners connect with a private code and raise **Ziggy** together  feeding, playing, sending photos and little love notes that sync between their phones in real time.

> Think of it as a Tamagotchi you and your partner keep alive together — every action one person takes shows up instantly on the other's screen.

---

## ✨ Features

- 🐶 **One shared pet, live-synced** — hunger, happiness, energy and a "love score" update in real time across both phones via Firestore snapshot listeners.
- 💞 **Private pairing** — partners link up with a generated "love code"; all data lives under that relationship.
- 📸 **Instants** — snap a photo (in-app camera or gallery), drag a caption anywhere on it, and send it. Ephemeral by design: a new instant replaces the old one, so images don't pile up.
- 💌 **One-tap love notes** — quick emotion messages (Miss You, Good Night, Hug…) that reorder by how often you use them, plus a **custom note composer with an emotion picker** that sets the exact Ziggy face your partner sees.
- 🎭 **Emotional Ziggy** — the mascot's expression reflects mood, incoming messages, and pending instants.
- ❓ **Daily questions** — a shared question each day; answers reveal once both partners respond.
- 🎮 **Mini-games** — feeding, collaborative drawing/tracing, and a pizza-making activity.
- 🕰️ **Activity timeline** — "Our Memories," a cute log of everything you've done together, with one-tap clear.
- 🔔 **Local notifications** for when Ziggy needs attention.
- 🧩 **Home Screen widget** (WidgetKit) showing Ziggy's current state.
- 🗑️ **Privacy-first** — in-app data deletion that wipes the relationship's data from the server.

---

## 🛠️ Tech Stack

| Area | Tech |
|------|------|
| UI | SwiftUI |
| Realtime backend | Firebase Firestore (snapshot listeners + transactions) |
| Widget | WidgetKit + App Groups |
| Media | PhotosUI, UIImagePickerController (camera) |
| Notifications | UserNotifications (local) |
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
├─ Views/          Onboarding, RelationshipSetup, Home (ContentView), Feed, Instant, Activity, Settings, games
├─ Ziggy/          App entry point, assets, Firebase config
└─ ZiggyWidget/    Home Screen widget extension
```

---

## 🚀 Getting Started

### Requirements
- Xcode 16+
- iOS 17+ device or simulator
- A Firebase project (free Spark plan works for development)



## 🗺️ Roadmap

- [ ] Production-grade Firestore security rules
- [ ] App Check
- [ ] Privacy manifest + App Store privacy labels
- [ ] Move instant images to Firebase Storage
- [ ] Lower deployment target for wider device support

---


