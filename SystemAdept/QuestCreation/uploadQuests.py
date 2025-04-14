#!/usr/bin/env python3
import csv
import argparse
import os
import firebase_admin
from firebase_admin import credentials, firestore

# === Initialize Firebase Admin SDK ===
# Expects a file named serviceAccountKey.json in the same directory.
SERVICE_ACCOUNT_PATH = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
if not os.path.isfile(SERVICE_ACCOUNT_PATH):
    raise FileNotFoundError(f"Could not find {SERVICE_ACCOUNT_PATH}")

cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

def load_csv_files(csv_paths):
    """
    Reads all CSVs and groups rows by questSystemName.
    Returns: dict[str, list[dict]] mapping system name → list of row‐dicts
    """
    systems = {}
    for path in csv_paths:
        with open(path, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                name = row["questSystemName"]
                systems.setdefault(name, []).append(row)
    return systems

def clear_subcollection(doc_ref, subcol_name):
    """
    Deletes all documents in the given subcollection.
    """
    for subdoc in doc_ref.collection(subcol_name).stream():
        subdoc.reference.delete()

def upload_system(system_name, rows):
    """
    For a single questSystemName:
      - Ensure the system doc exists (and set its 'name' field).
      - Clear its existing quests subcollection.
      - Upload each row as a new quest document.
    """
    # 1) Create/update the questSystem document
    system_ref = db.collection("questSystems").document(system_name)
    system_ref.set({"name": system_name}, merge=True)

    # 2) Clear existing quests
    subcol = f"{system_name} Quests"
    clear_subcollection(system_ref, subcol)

    # 3) Upload new quests
    for row in rows:
        quest_name   = row["questName"]
        quest_rank   = row["questRank"]
        quest_prompt = row["questPrompt"]
        aura         = row["questAuraGranted"]
        count        = row["questEventCount"]
        units        = row["questEventUnits"]

        # document ID can be questName + rank
        doc_id = f"{quest_name}_{quest_rank}"
        quest_ref = system_ref.collection(subcol).document(doc_id)

        quest_data = {
            "questName":        quest_name,
            "questRank":        int(quest_rank),
            "questPrompt":      quest_prompt,
            "questAuraGranted": float(aura),
            "questEventCount":  float(count),
            "questEventUnits":  units
        }
        quest_ref.set(quest_data)
        print(f"  ↳ Uploaded '{quest_name}' (rank {quest_rank})")

def main():
    parser = argparse.ArgumentParser(
        description="Upload/replace quest CSV(s) to Firestore (no questRepeatDebuff)."
    )
    parser.add_argument(
        "csv_files", nargs="+",
        help="One or more CSV files (with columns: questSystemName,questName,questRank,questPrompt,questAuraGranted,questEventCount,questEventUnits)"
    )
    args = parser.parse_args()

    # 1) Read & group all CSV rows by system
    systems = load_csv_files(args.csv_files)

    # 2) For each system, clear & re-upload
    for system_name, rows in systems.items():
        print(f"Processing system: {system_name}")
        upload_system(system_name, rows)

    print("All done!")

if __name__ == "__main__":
    main()
