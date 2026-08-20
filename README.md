# Ziggy

A SwiftUI companion app for couples, built around a single shared virtual pet.

Two people pair with a private code and look after Ziggy together — feeding, playing, drawing and sending short notes that sync between both phones in real time. Anything one partner does appears on the other's screen within seconds, and on their Home Screen widget without either of them opening the app.

Available on the [App Store](https://apps.apple.com/app/id6785883853).

---

## Features

**Shared pet**
One pet, two phones. Hunger, happiness, energy and a love score stay in sync across both devices through Firestore snapshot listeners. Ziggy's expression follows the time of day, goes hungry in the evening if neither partner has fed him, and reflects whatever was last sent.

**Pairing**
Partners link with a generated code or a shared invite link. All relationship data is scoped to that pairing. Code generation runs inside a transaction so a collision fails and is retried rather than overwriting an existing couple.

**Accounts**
Sign in with Apple, offered but never required. The credential is linked to the existing anonymous account rather than replacing it, so the Firebase uid is preserved and no data is detached. A signed-in user who reinstalls or changes phone has their name and relationship restored automatically, from the keychain first and a Firestore lookup as a fallback. Users who decline keep the previous device-bound behaviour.

**Scrapbook**
A shared, page-based scrapbook. The shelf is an open bookcase holding books and decorative objects that can be dragged into any position across any row. Books open with a page-turn animation over the shelf, showing two leaves at a time.

The page editor supports photos with twelve recolourable frames, seven brushes, text in sixteen fonts, emoji, cut-out ransom-note letters with independent paper and ink colours, and fifteen drawn paper stickers. Paper stickers can carry typed captions or hold a photo inside them. Every element can be moved, scaled, rotated and locked, and all of it syncs per element so both partners can work on the same page at once. A finished book can be exported as a vector PDF.

**Doodle**
A PencilKit canvas with seven pen types, a hold-and-slide colour picker, custom canvas backgrounds, and on-canvas text. Finished drawings appear on the partner's Home Screen widget within seconds. A doodle can be pinned so it stays on the widget until replaced, and either partner's drawing can be saved to the photo library.

**Instants**
Photos from the camera or library with a draggable caption. The current instant remains deliberately ephemeral — each new one replaces it — but every instant is also kept in an archive, browsable as a dated grid with full-screen viewing, saving to Photos, and sender-only deletion.

**Notes**
One-tap messages that reorder by frequency of use, plus a custom composer that floats above the keyboard and lets the sender choose which expression Ziggy wears on delivery.

**Games**
Five real-time two-player games: Trace Together, Tic Tac Toe, Connect 4, Dots and Boxes and Memory Match. Each has a shared lobby and ready-up flow, with results tallied server-side into a persistent scoreboard.

**Daily questions**
A shared prompt each day drawn from a bank of over 200. Answers are revealed once both partners have responded.

**Home Screen widget**
A WidgetKit extension showing Ziggy's current mood in a room that follows the clock, the partner's latest message, or their most recent doodle. Includes a guided walkthrough for adding it, since iOS provides no way to install a widget programmatically.

**Notifications**
Push notifications through Cloud Functions and APNs when a partner feeds Ziggy, plays a game, or sends a note, instant or doodle. A single daily reminder in the evening, sent only if neither partner has fed him that day.

**Activity timeline**
A live-synced log of both partners' actions, presented as a shared conversation.

---

## Tech stack

| Area | Technology |
|------|------------|
| UI | SwiftUI |
| Realtime backend | Cloud Firestore (snapshot listeners, transactions, batched writes) |
| Authentication | Firebase Anonymous Auth, Sign in with Apple |
| Credential storage | Keychain Services, synchronised via iCloud Keychain |
| Push notifications | Cloud Functions (TypeScript) with APNs |
| Analytics | Firebase Analytics |
| Widget | WidgetKit, App Groups |
| Drawing | PencilKit, SwiftUI Canvas |
| Media | PhotosUI, Photos, UIImagePickerController |
| Export | ImageRenderer, UIGraphicsPDFRenderer |
| Local notifications | UserNotifications |
| Persistence | UserDefaults with a local cache |
| Architecture | MVVM with service singletons |

---

## Architecture

State flows through an observable `PetViewModel`, with focused services handling each concern.

```
Views (SwiftUI)
   |  observe
   v
PetViewModel
   |
   +- FirestoreManager        realtime sync, messages, instants, games, scoreboard
   +- ScrapbookManager        shelf, pages and per-element scrapbook sync
   +- ZiggyAccount            Sign in with Apple, linking and account recovery
   +- RelationshipManager     pairing and relationship code
   +- PersistenceManager      local pet cache
   +- WidgetDataManager       shared App Group store
   +- NotificationManager     local and scheduled reminders
   +- DailyQuestionManager    daily prompts
```

`Pet` is compiled into both the app and the widget extension, so mood logic cannot drift between the two.

### Data model

Everything belonging to a couple lives beneath a single document, which keeps access control to one rule:

```
relationships/{code}
├─ members[]                     the uids permitted to read and write
├─ data/                         pet, emotions, instant, doodle, games, scores
├─ instants/{id}                 the kept instant archive
├─ devices/{uid}                 push tokens
├─ dailyQuestions/{id}
├─ scrapbookMeta/shelf           ornament arrangement
└─ scrapbooks/{book}
   └─ pages/{page}
      └─ elements/{element}      one document per element on a page
```

Scrapbook elements are stored one document per element rather than one per page. A page holding several photos would otherwise approach Firestore's 1 MB document ceiling, and per-element writes let both partners rearrange the same page without overwriting each other.

### Project structure

```
Ziggy/
├─ Models/           Pet, Event, UserManager
├─ Services/         PetViewModel and the Firestore, Relationship, Persistence,
│                    Widget, Notification and DailyQuestion managers
├─ Views/            Onboarding, pairing, home, feed, instant, activity,
│                    settings, play centre, widget walkthrough
├─ Ziggy/            App entry point, assets, Firebase config, Doodle, games,
│                    account and keychain, instant archive, and the scrapbook
│                    (shelf, book, canvas, elements, decorations, PDF export)
├─ ZiggyWidget/      Home Screen widget extension
├─ functions/        Cloud Functions (TypeScript) for partner notifications,
│                    and maintenance scripts
└─ firestore.rules   Membership-scoped security rules
```

---

## Security

`firestore.rules` restricts every document beneath a relationship to the uids listed in its `members` array, and caps membership at two. The cap is what makes a guessed pairing code far less useful: a relationship whose second partner has already joined cannot admit a third.

Because a member is a device identity rather than a person, a partner who never signed in and then changes phone would otherwise be permanently locked out by their own stale identity. Settings therefore includes an action that clears the other member, freeing a place so they can rejoin.

`functions/scripts/audit-members.js` reports any relationship missing a `members` array — which the rules would lock out — and repairs what it can from the `devices` subcollection. It should be run before the rules are deployed.

---

## Getting started

### Requirements

- Xcode 16 or later
- iOS 17 or later
- A Firebase project (the free Spark plan is sufficient for development)

### Setup

1. Clone the repository and open `Ziggy.xcodeproj`.
2. Create a Firebase project and register an iOS app with the bundle identifier used by the target.
3. Download `GoogleService-Info.plist` and place it in the `Ziggy/` directory.
4. Enable Anonymous Authentication, Apple as a sign-in provider, and Cloud Firestore in the Firebase console.
5. Enable the Sign in with Apple capability on the App ID in the Apple Developer portal.
6. Set the App Group identifier on both the app and widget targets so they share a container.
7. Deploy the Cloud Functions in `functions/` if push notifications are required. They expect APNs credentials to be configured as secrets.
8. Run the membership audit, then deploy the rules with `firebase deploy --only firestore:rules`.

---

## Roadmap

- Subscription tier covering the scrapbook, the instant archive and saving to Photos
- Firebase App Check
- Move instant, doodle and scrapbook images to Cloud Storage, currently encoded into Firestore documents
- Approval step when joining an existing relationship
- Unit test coverage for mood, scoring and scheduling logic
- iPad layout

---

## Licence

All rights reserved. This repository is public for reference; the app and its assets are not licensed for redistribution.
