# Security rule tests

`firestore.rules` decides who can read a couple's photos, messages and
scrapbook. It is the one file in this repository where a mistake is silent:
nothing fails to build, no screen looks wrong, and the damage is only visible
from outside. These tests run the real rules against the Firestore emulator so
that a mistake fails here instead.

Run them before every rules deploy.

## Running

Requires Java, which the Firestore emulator needs:

    brew install openjdk

Then, from this directory:

    npm install
    npm test

## What they cover

Pairing — reading a code nobody holds, claiming it, a partner joining. This is
the path every new couple takes, and the one most easily broken by a rule
written to protect something else.

Protection — a stranger claiming a taken code, a third person joining, a
non-member reading the relationship or the scrapbook inside it, an outsider
granting themselves a subscription.

Recovery — a member freeing a lost partner's place so they can rejoin.

Deletion — a member deleting their own relationship, which Settings offers and
Apple requires, and a non-member being refused.
