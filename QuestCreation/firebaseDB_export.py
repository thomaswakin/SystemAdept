#!/usr/bin/env python3
import firebase_admin
from firebase_admin import credentials, firestore
import yaml
import argparse

def merge_schemas(s1, s2):
    """
    Recursively merge two schemas.
    If there is any type conflict, the field is marked as "mixed".
    Also, merges the 'subcollections' section if it exists.
    """
    if s1 == s2:
        return s1
    if s1 == "mixed" or s2 == "mixed":
        return "mixed"
    if isinstance(s1, str) and isinstance(s2, str):
        return s1 if s1 == s2 else "mixed"
    if isinstance(s1, dict) and isinstance(s2, dict):
        if s1.get("type") == s2.get("type"):
            if s1["type"] == "object":
                merged_properties = {}
                keys = set(s1.get("properties", {}).keys()) | set(s2.get("properties", {}).keys())
                for key in keys:
                    if key in s1.get("properties", {}) and key in s2.get("properties", {}):
                        merged_properties[key] = merge_schemas(s1["properties"][key], s2["properties"][key])
                    elif key in s1.get("properties", {}):
                        merged_properties[key] = s1["properties"][key]
                    else:
                        merged_properties[key] = s2["properties"][key]
                merged = {"type": "object", "properties": merged_properties}
                # Merge any subcollections if they exist.
                sub1 = s1.get("subcollections", {})
                sub2 = s2.get("subcollections", {})
                if sub1 or sub2:
                    merged_sub = {}
                    keys_sub = set(sub1.keys()) | set(sub2.keys())
                    for key in keys_sub:
                        if key in sub1 and key in sub2:
                            merged_sub[key] = merge_schemas(sub1[key], sub2[key])
                        elif key in sub1:
                            merged_sub[key] = sub1[key]
                        else:
                            merged_sub[key] = sub2[key]
                    merged["subcollections"] = merged_sub
                return merged
            elif s1["type"] == "array":
                merged_items = merge_schemas(s1.get("items"), s2.get("items"))
                return {"type": "array", "items": merged_items}
            else:
                return "mixed"
        else:
            return "mixed"
    return "mixed"

def infer_schema(value):
    """
    Infers the schema for a value recursively.
    For dictionaries and lists, a nested schema is produced.
    """
    if isinstance(value, dict):
        properties = {}
        for k, v in value.items():
            properties[k] = infer_schema(v)
        return {"type": "object", "properties": properties}
    elif isinstance(value, list):
        if not value:
            return {"type": "array", "items": None}
        else:
            item_schema = None
            for item in value:
                current_schema = infer_schema(item)
                if item_schema is None:
                    item_schema = current_schema
                else:
                    item_schema = merge_schemas(item_schema, current_schema)
            return {"type": "array", "items": item_schema}
    else:
        if isinstance(value, bool):
            return "boolean"
        elif isinstance(value, int):
            return "integer"
        elif isinstance(value, float):
            return "float"
        elif isinstance(value, str):
            return "string"
        elif value is None:
            return "null"
        else:
            return type(value).__name__

def get_document_schema(doc):
    """
    Returns a complete recursive schema for a document.
    This includes the document fields (via infer_schema) and any subcollections.
    """
    data = doc.to_dict()
    base_schema = infer_schema(data)
    subcollections = {}
    # Retrieve all subcollections for this document.
    for subcoll in doc.reference.collections():
        print(f"Scanning subcollection '{subcoll.id}' of document '{doc.id}'")
        subcoll_schema = get_collection_schema(subcoll)
        subcollections[subcoll.id] = subcoll_schema
    if subcollections:
        if isinstance(base_schema, dict) and base_schema.get("type") == "object":
            base_schema["subcollections"] = subcollections
        else:
            base_schema = {"type": "object", "properties": base_schema, "subcollections": subcollections}
    return base_schema

def get_collection_schema(collection_ref):
    """
    Iterates over all documents in a collection and aggregates a complete
    recursive schema including an example document.
    Returns a dictionary with two keys:
      - "schema": the aggregated schema for the collection
      - "example": an example document's schema
    """
    aggregated_schema = None
    example_document = None
    for doc in collection_ref.stream():
        ds = get_document_schema(doc)
        if example_document is None:
            example_document = ds
        if aggregated_schema is None:
            aggregated_schema = ds
        else:
            aggregated_schema = merge_schemas(aggregated_schema, ds)
    result = {}
    if aggregated_schema is not None:
        result["schema"] = aggregated_schema
    if example_document is not None:
        result["example"] = example_document
    return result

def get_firestore_schema(db):
    """
    Retrieves the complete recursive schema for each root-level collection
    in your Firestore database.
    Returns a dictionary mapping collection names to their detailed schemas.
    """
    firestore_schema = {}
    for collection in db.collections():
        print(f"Scanning collection: {collection.id}")
        col_schema = get_collection_schema(collection)
        firestore_schema[collection.id] = col_schema
    return firestore_schema

def main():
    parser = argparse.ArgumentParser(description='Download a recursive YAML schema of your Firestore collections including subcollections.')
    parser.add_argument('-c', '--creds', required=True, help='Path to the Firebase service account JSON file')
    parser.add_argument('-o', '--output', help='Path to the output YAML file. If not provided, output is printed to screen.')
    args = parser.parse_args()
    
    # Initialize the Firebase Admin SDK.
    cred = credentials.Certificate(args.creds)
    firebase_admin.initialize_app(cred)
    
    # Create a Firestore client.
    db = firestore.client()
    
    # Retrieve the complete recursive schema.
    schema = get_firestore_schema(db)
    
    # Convert the schema to YAML format.
    yaml_output = yaml.dump(schema, sort_keys=False, default_flow_style=False)
    
    # Either write to file or print to screen.
    if args.output:
        with open(args.output, 'w') as outfile:
            outfile.write(yaml_output)
        print("Schema has been saved to:", args.output)
    else:
        print(yaml_output)

if __name__ == "__main__":
    main()

