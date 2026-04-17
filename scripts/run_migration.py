#!/usr/bin/env python3
"""Run Supabase migrations via Management API"""
import json, urllib.request, sys

SBP_TOKEN = "sbp_9746862bcf41f19caace926a197b8f118d1b0e52"
PROJECT_ID = "pqhwesvkdwyzlexmtnwp"
BASE = f"https://api.supabase.com/v1/projects/{PROJECT_ID}/database/query"

def run_sql(sql):
    data = json.dumps({"query": sql}).encode()
    req = urllib.request.Request(BASE, data=data, headers={
        "Authorization": f"Bearer {SBP_TOKEN}",
        "Content-Type": "application/json"
    })
    try:
        resp = urllib.request.urlopen(req)
        return resp.read().decode()
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return f"ERROR ({e.code}): {body}"

migration_file = sys.argv[1] if len(sys.argv) > 1 else "supabase/migrations/001_base_schema.sql"
with open(migration_file) as f:
    full_sql = f.read()

result = run_sql(full_sql)
print(result[:2000])
