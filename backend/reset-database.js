/**
 * Reset the Firestore database to a clean slate.
 *
 * This deletes EVERY document in EVERY top-level collection (users, groups,
 * expenses, incomes, debts, chats, kyc, etc.). After running, no accounts exist
 * - every user must register again, and their fresh id is stored on sign-up.
 *
 * SAFETY: This is destructive and irreversible. It only runs when you pass the
 * explicit --confirm flag:
 *
 *     node reset-database.js --confirm
 *
 * (or via npm)   npm run reset-db -- --confirm
 */

require('dotenv').config();
const { initializeFirebase, getDb } = require('./src/config/firebase');

const BATCH_LIMIT = 400; // Firestore batch max is 500; keep margin.

async function deleteCollection(db, collectionRef) {
    let deleted = 0;
    while (true) {
        const snapshot = await collectionRef.limit(BATCH_LIMIT).get();
        if (snapshot.empty) break;

        const batch = db.batch();
        snapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        deleted += snapshot.size;

        if (snapshot.size < BATCH_LIMIT) break;
    }
    return deleted;
}

async function resetDatabase() {
    if (!process.argv.includes('--confirm')) {
        console.log('\n⚠️  This will DELETE ALL DATA in Firestore (all users and records).');
        console.log('    Nothing was deleted. Re-run with the --confirm flag to proceed:\n');
        console.log('    node reset-database.js --confirm\n');
        process.exit(1);
    }

    console.log('🔥 Initializing Firebase...');
    initializeFirebase();
    const db = getDb();

    console.log('🧹 Fetching top-level collections...');
    const collections = await db.listCollections();

    if (collections.length === 0) {
        console.log('✅ Database is already empty. Nothing to do.');
        return;
    }

    let total = 0;
    for (const collectionRef of collections) {
        process.stdout.write(`   • Clearing "${collectionRef.id}"... `);
        const count = await deleteCollection(db, collectionRef);
        total += count;
        console.log(`removed ${count} document(s)`);
    }

    console.log(`\n✅ Fresh start complete. Deleted ${total} document(s) across ${collections.length} collection(s).`);
    console.log('   Every user must now register again to be stored in the database.');
}

resetDatabase()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('❌ Reset failed:', err.message);
        process.exit(1);
    });
