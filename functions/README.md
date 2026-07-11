# Ziggy Widget Push Function

This Cloud Function sends a silent APNs push to the partner's iPhone whenever a
new document is created in:

`relationships/{relationshipId}/emotions/{emotionId}`

The iOS app receives that silent push, writes the event into the shared App
Group widget store, and reloads the Ziggy widget.

## Required Apple Secrets

Create an APNs Auth Key in Apple Developer:

1. Apple Developer > Certificates, Identifiers & Profiles > Keys.
2. Add a key with Apple Push Notifications service enabled.
3. Download the `.p8` file once.
4. Copy the Key ID and your Team ID.

Then set Firebase Function secrets:

```sh
firebase functions:secrets:set APNS_AUTH_KEY
firebase functions:secrets:set APNS_KEY_ID
firebase functions:secrets:set APNS_TEAM_ID
```

For `APNS_AUTH_KEY`, paste the full `.p8` file contents including the
`BEGIN PRIVATE KEY` and `END PRIVATE KEY` lines.

## Deploy

```sh
npm --prefix functions install
firebase deploy --only functions
```

The function is configured for production APNs because this is for the App Store
build. For local development pushes, change `production: true` in
`functions/src/index.ts` to `false`.
