/*
 * audit-members.js
 *
 * Run this BEFORE deploying firestore.rules.
 *
 * The new rules let only the uids in a relationship's `members` array read or
 * write anything inside it. Any relationship that predates the app writing that
 * array would be locked out the moment the rules go live — and its owners would
 * see an app that has forgotten their pet and lost their scrapbook.
 *
 * This script finds those relationships and, where it can, repairs them.
 *
 * It can repair them because `devices/{uid}` is keyed by the same uid that
 * belongs in `members`: anyone who allowed notifications left their id there.
 * Where there is no device document either, the relationship is reported and
 * left alone — there is nothing to recover it from, and guessing would be
 * worse than leaving it.
 *
 *   node scripts/audit-members.js            # report only, changes nothing
 *   node scripts/audit-members.js --fix      # repair what it can
 *
 * Needs application default credentials:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const FIX = process.argv.includes("--fix");

async function main() {
  const relationships = await db.collection("relationships").get();

  let healthy = 0;
  const repairable = [];
  const stranded = [];
  const oversized = [];

  for (const doc of relationships.docs) {
    const members = doc.get("members");

    if (Array.isArray(members) && members.length > 0) {
      healthy++;
      // Worth knowing about separately: the rules cap membership at two, but
      // they do not retroactively trim anything already larger.
      if (members.length > 2) oversized.push({ code: doc.id, count: members.length });
      continue;
    }

    const devices = await doc.ref.collection("devices").get();
    const uids = devices.docs.map((d) => d.id).filter(Boolean);

    if (uids.length > 0) {
      repairable.push({ code: doc.id, uids: uids.slice(0, 2) });
    } else {
      stranded.push(doc.id);
    }
  }

  console.log(`\nrelationships scanned : ${relationships.size}`);
  console.log(`already have members  : ${healthy}`);
  console.log(`repairable from devices: ${repairable.length}`);
  console.log(`no way to recover      : ${stranded.length}`);
  console.log(`more than two members  : ${oversized.length}`);

  if (oversized.length) {
    console.log("\nRelationships with more than two members — worth a look, as");
    console.log("each extra uid is someone who joined a code that was not theirs:");
    oversized.forEach((r) => console.log(`  ${r.code}  (${r.count})`));
  }

  if (stranded.length) {
    console.log("\nThese will lose access when the rules go live:");
    stranded.forEach((code) => console.log(`  ${code}`));
    console.log("\nThey have no device document to recover a uid from. Either");
    console.log("leave them (they can re-pair with the same code and their data");
    console.log("is still there), or hold the rules back a release so the app");
    console.log("can write membership for them first.");
  }

  if (!FIX) {
    console.log("\nReport only. Re-run with --fix to repair the repairable ones.\n");
    return;
  }

  for (const { code, uids } of repairable) {
    await db.collection("relationships").doc(code).set({ members: uids }, { merge: true });
    console.log(`repaired ${code} -> ${uids.join(", ")}`);
  }

  console.log(`\nrepaired ${repairable.length} relationships\n`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
