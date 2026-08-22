// Exercises firestore.rules against the real Firestore emulator.
//
// The question that matters: can a new couple still pair once these rules are
// live? Everything else here is the protection those rules exist for.

const fs = require("fs");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");

const RULES = require("path").join(__dirname, "..", "firestore.rules");

let passed = 0;
let failed = 0;

async function check(name, promise) {
  try {
    await promise;
    console.log(`  PASS  ${name}`);
    passed++;
  } catch (e) {
    console.log(`  FAIL  ${name}`);
    console.log(`        ${String(e).split("\n")[0]}`);
    failed++;
  }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: "ziggy-rules-test",
    firestore: {
      rules: fs.readFileSync(RULES, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });

  const alice = env.authenticatedContext("alice").firestore();
  const bob = env.authenticatedContext("bob").firestore();
  const mallory = env.authenticatedContext("mallory").firestore();
  const stranger = env.unauthenticatedContext().firestore();

  console.log("\nPAIRING — the path every new couple takes\n");

  // The fix. Claiming a code reads the document first; if that read is
  // denied, nobody can ever start a relationship.
  await check(
    "read a code nobody holds",
    assertSucceeds(alice.doc("relationships/ABC123").get())
  );

  await check(
    "claim a free code with yourself as the only member",
    assertSucceeds(
      alice.doc("relationships/ABC123").set({
        createdAt: new Date(),
        members: ["alice"],
      })
    )
  );

  await check(
    "partner joins by adding only themselves",
    assertSucceeds(
      bob.doc("relationships/ABC123").set(
        { members: ["alice", "bob"] },
        { merge: true }
      )
    )
  );

  console.log("\nPROTECTION — what the rules are for\n");

  await check(
    "a stranger cannot claim a code that is taken",
    assertFails(
      mallory.doc("relationships/ABC123").set(
        { members: ["mallory"] },
        { merge: true }
      )
    )
  );

  await check(
    "a third person cannot join a full relationship",
    assertFails(
      mallory.doc("relationships/ABC123").set(
        { members: ["alice", "bob", "mallory"] },
        { merge: true }
      )
    )
  );

  await check(
    "a non-member cannot read the relationship",
    assertFails(mallory.doc("relationships/ABC123").get())
  );

  await check(
    "a non-member cannot read the scrapbook inside it",
    assertFails(mallory.doc("relationships/ABC123/books/b1").get())
  );

  await check(
    "a member can write inside it",
    assertSucceeds(
      alice.doc("relationships/ABC123/books/b1").set({ title: "Us" })
    )
  );

  await check(
    "the partner can read what the other wrote",
    assertSucceeds(bob.doc("relationships/ABC123/books/b1").get())
  );

  await check(
    "signed out reads nothing, even a free code",
    assertFails(stranger.doc("relationships/ZZZ999").get())
  );

  // The recursive wildcard covering everything inside also matched the
  // relationship document itself, and being broader it won — letting a member
  // sidestep the two-member cap the rules above take such care over.
  await check(
    "a member cannot add a third person past the cap",
    assertFails(
      alice.doc("relationships/ABC123").set(
        { members: ["alice", "bob", "mallory"] },
        { merge: true }
      )
    )
  );

  await check(
    "a non-member cannot delete the relationship",
    assertFails(mallory.doc("relationships/ABC123").delete())
  );

  console.log("\nSUBSCRIPTION — the entitlement lives on the relationship\n");

  await check(
    "a member can read the entitlement",
    assertSucceeds(alice.doc("relationships/ABC123").get())
  );

  await check(
    "an outsider cannot grant themselves one",
    assertFails(
      mallory.doc("relationships/ABC123").set(
        { activeUntil: new Date(2030, 0, 1) },
        { merge: true }
      )
    )
  );

  console.log("\nRECOVERY — freeing a lost partner's place\n");

  await check(
    "a member can remove the other so they can rejoin",
    assertSucceeds(
      alice.doc("relationships/ABC123").set(
        { members: ["alice"] },
        { merge: true }
      )
    )
  );

  console.log("\nDELETION — Delete Everything, which Apple requires\n");

  // Last, because it destroys the fixture everything above depends on.
  await check(
    "a member can delete their own relationship",
    assertSucceeds(alice.doc("relationships/ABC123").delete())
  );

  await env.cleanup();

  console.log(`\n${passed} passed, ${failed} failed\n`);
  process.exit(failed === 0 ? 0 : 1);
})();
