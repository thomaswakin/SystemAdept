import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Adjust these to match your old subcollection name
OLD_SUBCOL = 'Walk System Quests'
NEW_SUBCOL = 'quests'

for system_doc in db.collection('questSystems').stream():
    old_qs = system_doc.reference.collection(OLD_SUBCOL).stream()
    batch = db.batch()
    for q in old_qs:
        data = q.to_dict()
        new_ref = system_doc.reference.collection(NEW_SUBCOL).document(q.id)
        batch.set(new_ref, data)
    batch.commit()
    print(f"Migrated {system_doc.id}")
