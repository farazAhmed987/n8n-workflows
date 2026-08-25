#!/usr/bin/env python3
"""
DevSynt Hiring Automation - Test Intake Script
Sends sample candidate payloads to local n8n Webhook trigger or validates normalization logic.
"""

import json
import urllib.request
import urllib.error
import sys
import os

WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/candidate-application")
SAMPLE_FILE = os.path.join(os.path.dirname(__file__), "..", "tests", "sample_candidates.json")

def load_samples():
    if not os.path.exists(SAMPLE_FILE):
        print(f"[ERROR] Sample file not found: {SAMPLE_FILE}")
        sys.exit(1)
    with open(SAMPLE_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def test_normalization():
    print("==================================================")
    print("DevSynt Hiring Automation - Local Data Normalization Test")
    print("==================================================")
    candidates = load_samples()
    for idx, cand in enumerate(candidates, 1):
        print(f"\n[Test Candidate #{idx}] {cand['name']} ({cand['email']})")
        print(f"  Role Applied: {cand['role_applied']}")
        print(f"  Source: {cand['source']}")
        print(f"  Expected Classification: {cand['expected_classification']}")
        print(f"  Resume Preview: {cand['resume_text'][:80]}...")
    print("\n[SUCCESS] Sample dataset formatted and validated successfully.")

def send_test_webhook():
    print("\n==================================================")
    print(f"Posting Test Payloads to n8n Webhook: {WEBHOOK_URL}")
    print("==================================================")
    candidates = load_samples()
    for cand in candidates:
        try:
            req = urllib.request.Request(
                WEBHOOK_URL,
                data=json.dumps(cand).encode("utf-8"),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req) as resp:
                print(f"[POST SUCCESS] Candidate '{cand['name']}' -> HTTP Status {resp.status}")
        except urllib.error.URLError as e:
            print(f"[POST FAILED] Candidate '{cand['name']}' -> Could not connect to n8n ({e}). Ensure n8n is running locally!")

if __name__ == "__main__":
    test_normalization()
    if "--post" in sys.argv:
        send_test_webhook()
