import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

systems = db.collection('questSystems').list_documents()
for sys_ref in systems:
    quests = sys_ref.collection('quests').stream()
    batch = db.batch()
    for q in quests:
        data = q.to_dict()
        updates = {}
        # Only convert if it's a string
        if isinstance(data.get('questRank'), str):
            updates['questRank'] = int(data['questRank'])
        if isinstance(data.get('questAuraGranted'), str):
            updates['questAuraGranted'] = float(data['questAuraGranted'])
        if isinstance(data.get('questEventCount'), str):
            updates['questEventCount'] = float(data['questEventCount'])
        # …repeat for any other numeric fields…
        if updates:
            batch.update(q.reference, updates)
    batch.commit()
    print(f"Migrated system {sys_ref.id}")
