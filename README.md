# Ziggy 🐶

A SwiftUI + Firebase **couple's companion app** built around one shared virtual pet. Two partners connect with a private code and raise **Ziggy** together  feeding, playing, sending photos and little love notes that sync between their phones in real time.

> Think of it as a Tamagotchi you and your partner keep alive together  every action one person takes shows up instantly on the other's screen.

---

## ✨ Features

- 🐶 **One shared pet, live-synced** — hunger, happiness, energy and a "love score" update in real time across both phones via Firestore snapshot listeners.
- 💞 **Private pairing** — partners link up with a generated "love code" or a tap-to-join invite link; all data lives under that relationship. A one-time cute **"You're Connected!"** popup celebrates the moment both partners first join, then never shows again.
- 📸 **Instants** — snap a photo (in-app camera or gallery), drag a caption anywhere on it, and send it. Ephemeral by design: a new instant replaces the old one, so images don't pile up.
- 🎨 **Doodle** — draw a sketch with PencilKit (7 pen types including fountain pen, watercolor, and crayon, a 16-color palette, text/emoji stickers, and a bold adjustable brush) and it shows up live, edge-to-edge, on your partner's Home Screen widget. Tap a partner's doodle to see it full-size, and optionally **pin** a doodle so it stays on the widget until you send a new one, instead of being replaced by the next message.
- 💌 **One-tap love notes** — quick emotion messages (Miss You, Good Night, Hug…) that reorder by how often you use them, plus a **custom note composer** that floats above the keyboard (not a sheet), with an emotion picker that sets the exact Ziggy face your partner sees.
- 🔔 **Home Screen popups** — a Ziggy-themed popup surfaces the moment your partner sends a Doodle or an Instant, separate from the in-app preview.
- 🎭 **Emotional Ziggy** — the mascot's expression reflects mood, incoming messages, and pending instants — and now decays more honestly if nobody's shown Ziggy attention in a while. Rename Ziggy in Settings and the name propagates everywhere — header, activity feed (past **and** future memories), notifications, widget.
- ❓ **Daily questions** — a shared question each day from a bank of 200+, so it doesn't repeat for over six months; answers reveal once both partners respond.
- 🎮 **Mini-games** — **Trace Together**, a live collaborative two-player drawing game across nine shapes; **Tic Tac Toe**, **Connect 4**, and **Dots and Boxes**, real-time networked matches with server-validated moves — all with a shared lobby/ready-up flow and a love-score reward on completion.
- 🏆 **Scoreboard** — a persistent win tally across every competitive mini-game, tallied server-side the instant a match ends (not by an easily-doubled "claim" tap), with a per-game breakdown and a one-tap reset for both partners.
- 🕰️ **Activity timeline** — "Our Memories," a shared, live-synced log of everything **both** partners have done, styled as mirrored chat bubbles.
- 🔔 **Push + local notifications** — real alerts (Cloud Functions + APNs) when your partner feeds, plays, sends a note, an Instant, a Doodle, or invites you to a game; local reminders when Ziggy needs attention; and a once-daily evening nudge to feed Ziggy — but only if neither partner has fed them yet that day.
- 🧩 **Home Screen widget** (WidgetKit) showing Ziggy's current state, your partner's latest message, or their live (optionally pinned) Doodle — with a one-time in-app walkthrough guiding new couples through adding it, since iOS gives apps no way to add a widget automatically.
- ⭐ **Cute rating prompt** — after a genuinely happy milestone, a custom in-app ask offers to open Apple's native App Store review sheet.
- 🗑️ **Privacy-first** — in-app data deletion that wipes the relationship's data from the server, plus a no-pressure "Continue without sharing" option on the invite screen for anyone who'd rather not share the link right away.

---

## 🛠️ Tech Stack

| Area | Tech |
|------|------|
| UI | SwiftUI |
| Realtime backend | Firebase Firestore (snapshot listeners + transactions) |
| Push notifications | Firebase Cloud Functions (TypeScript) + APNs |
| Analytics | Firebase Analytics |
| Widget | WidgetKit + App Groups |
| Drawing | PencilKit (Doodle with text/emoji stickers, Trace Together) |
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
   ├─ FirestoreManager      │  realtime sync, emotions, instants, games, scoreboard
   ├─ RelationshipManager   │  pairing / love code
   ├─ PersistenceManager    │  local pet cache
   ├─ WidgetDataManager     │  shared App Group store
   ├─ NotificationManager   │  local + daily feed reminders
   └─ DailyQuestionManager  │  daily prompts
```

### Project structure

```
Ziggy/
├─ Models/         Pet, Event, UserManager
├─ Services/       PetViewModel + Firestore/Relationship/Persistence/Widget/Notification/DailyQuestion managers
├─ Views/          Onboarding, RelationshipSetup, Home (ContentView), Feed, Instant, Activity, Settings, PlayCenter (games + Scoreboard), WidgetOnboarding, Trace Together
├─ Ziggy/          App entry point, assets, Firebase config, Doodle (PencilKit), Tic Tac Toe, Connect Four, Dots and Boxes
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


