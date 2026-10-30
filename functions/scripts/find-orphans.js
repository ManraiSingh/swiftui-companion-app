/*
 * find-orphans.js
 *
 * "Delete My Data" used to remove the relationship document but leave much of
 * what was nested under it, because Firestore does not delete nested data on
 * its own: photos, scrapbooks, bouquets, device tokens and park notes. Once the
 * relationship has gone the rules lock everyone out, so the app can never clean
 * these up. This script finds them, and with --delete removes them for good.
 *
 * Look at the report first. A relationship with no document is normally one of
 * these, but this deletes with no way back.
 *
 *   node scripts/find-orphans.js            # report only, changes nothing
 *   node scripts/find-orphans.js --delete   # delete what it reports
 *
 * Needs application default credentials:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function main() {
  const purge = process.argv.includes("--delete");

  // Unlike get(), this also lists documents that exist only as a parent of
  // something else, which is exactly what an orphan is.
  const refs = await db.collection("relationships").listDocuments();
  const orphans = [];

  for (const ref of refs) {
    const doc = await ref.get();
    if (doc.exists) continue;
    const collections = await ref.listCollections();
    orphans.push(ref);
    console.log(`orphan: ${ref.id}  (${collections.map((c) => c.id).join(", ")})`);
  }

  console.log(`\n${orphans.length} orphaned of ${refs.length} relationships.`);

  if (!purge) {
    if (orphans.length) console.log("Nothing changed. Run with --delete to remove them.");
    return;
  }

  for (const ref of orphans) {
    await db.recursiveDelete(ref);
    console.log(`deleted: ${ref.id}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
