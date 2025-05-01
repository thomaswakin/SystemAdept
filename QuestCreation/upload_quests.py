#!/usr/bin/env python3
"""
upload_quests.py

A script to upload quest system YAML files to Firestore, ensuring each quest has
required fields for `questAuraGranted`, `questEventCount`, and `questEventUnits`.

Usage:
    pip install firebase-admin pyyaml
    python upload_quests.py \
        --creds path/to/serviceAccountKey.json \
        (--input_dir path/to/quest-yamls/ | --file path/to/single-quest.yaml) \
        [--merge]

Options:
    --creds, -c       Path to your Firebase serviceAccountKey.json
    --input_dir, -i   Directory containing quest YAML files
    --file, -f        Path to a single quest YAML file
    --merge           Merge with existing documents instead of overwriting
"""
import os
import argparse
import re
import firebase_admin
from firebase_admin import credentials, firestore
import yaml


def upload_quest_systems(creds_path: str, file_paths: list[str], merge: bool):
    # Initialize Firebase Admin SDK once
    if not firebase_admin._apps:
        cred = credentials.Certificate(creds_path)
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    for file_path in file_paths:
        if not file_path.lower().endswith(('.yaml', '.yml')):
            print(f"Skipping non-YAML file '{file_path}'.")
            continue

        with open(file_path, 'r') as f:
            data = yaml.safe_load(f)

        # Required system fields
        system_id     = data.get('id')
        short_name    = data.get('shortName')
        description   = data.get('description')
        ttc           = data.get('defaultTimeToComplete', {})
        cooldown      = data.get('defaultQuestCooldown', {})
        repeat_debuff = data.get('defaultRepeatDebuff', 1.0)

        if not system_id or not short_name or not description:
            print(f"Skipping '{file_path}': 'id', 'shortName', and 'description' required.")
            continue

        # Upload system metadata
        system_data = {
            'name':        short_name,
            'description': description,
            'defaultTimeToComplete': ttc,
            'defaultQuestCooldown':  cooldown,
            'defaultRepeatDebuff':   repeat_debuff
        }
        system_ref = db.collection('questSystems').document(system_id)
        if merge:
            system_ref.set(system_data, merge=True)
        else:
            system_ref.set(system_data)
        print(f"Uploaded system '{system_id}' (shortName='{short_name}').")

        # Upload each quest with required fields
        quests_ref = system_ref.collection('quests')
        for quest in data.get('quests', []):
            quest_id = quest.get('questId')
            if not quest_id:
                print(f"  Skipping quest in '{file_path}': missing 'questId'.")
                continue

            # Ensure quest dict has all required properties
            qdict = dict(quest)
            # 1) Aura granted (default to rank)
            if 'questAuraGranted' not in qdict:
                qdict['questAuraGranted'] = float(qdict.get('rank', 0))
            # 2) Event count & units
            if 'questEventCount' not in qdict or 'questEventUnits' not in qdict:
                prompt = qdict.get('prompt', '')
                m = re.search(r"(\d+)", prompt)
                count = float(m.group(1)) if m else 0.0
                unit = 'minute' if 'minute' in prompt.lower() else 'rep'
                qdict['questEventCount'] = count
                qdict['questEventUnits'] = unit

            # Upload the quest document
            doc_ref = quests_ref.document(quest_id)
            if merge:
                doc_ref.set(qdict, merge=True)
            else:
                doc_ref.set(qdict)
            print(f"  Uploaded quest '{quest_id}'.")

    print('All quest systems uploaded successfully.')


def main():
    parser = argparse.ArgumentParser(
        description='Upload quest system YAML files to Firestore.'
    )
    parser.add_argument(
        '--creds', '-c', required=True,
        help='Path to your Firebase serviceAccountKey.json'
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--input_dir', '-i',
        help='Directory containing quest YAML files'
    )
    group.add_argument(
        '--file', '-f',
        help='Path to a single quest YAML file'
    )
    parser.add_argument(
        '--merge', action='store_true',
        help='Merge with existing documents instead of overwriting'
    )
    args = parser.parse_args()

    # Build list of files to upload
    if args.file:
        file_paths = [args.file]
    else:
        file_paths = [
            os.path.join(args.input_dir, f)
            for f in sorted(os.listdir(args.input_dir))
            if f.lower().endswith(('.yaml', '.yml'))
        ]

    upload_quest_systems(args.creds, file_paths, args.merge)

if __name__ == '__main__':
    main()
