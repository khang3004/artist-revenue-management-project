"""
Transform Step 1: Clean & Deduplicate Labels
Reads MusicBrainz label entities and normalizes them.

Output → data_lake/clean/labels.csv
"""

import json
import pandas as pd
from difflib import SequenceMatcher
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import MUSICBRAINZ_RAW, CLEAN_DIR


def _normalize(name: str) -> str:
    return " ".join(name.strip().split()).title()


def _are_similar(a: str, b: str, threshold=0.85) -> bool:
    return SequenceMatcher(None, a.lower(), b.lower()).ratio() >= threshold


def run():
    print("═══ Transform: Labels ═══")
    labels = {}

    # ── MusicBrainz labels ──────────────────────────────────────────────────
    mb_path = MUSICBRAINZ_RAW / "labels.json"
    if mb_path.exists():
        with open(mb_path, "r", encoding="utf-8") as f:
            mb_labels = json.load(f)
        for lab in mb_labels:
            raw = lab.get("name", "")
            if not raw:
                continue
            name = _normalize(raw)
            matched = False
            for existing in list(labels.keys()):
                if _are_similar(name, existing):
                    matched = True
                    break
            if not matched:
                labels[name] = {
                    "name": name,
                    "country": lab.get("country"),
                }

    # ── Also extract labels from artist releases ────────────────────────────
    art_path = MUSICBRAINZ_RAW / "artists.json"
    if art_path.exists():
        with open(art_path, "r", encoding="utf-8") as f:
            artists = json.load(f)
        for art in artists:
            for rel in art.get("releases", []):
                ln = rel.get("label_name")
                if ln:
                    name = _normalize(ln)
                    matched = False
                    for existing in list(labels.keys()):
                        if _are_similar(name, existing):
                            matched = True
                            break
                    if not matched:
                        labels[name] = {"name": name, "country": None}

    df = pd.DataFrame(labels.values())
    if len(df) > 0:
        df = df.drop_duplicates(subset=["name"])
    df.to_csv(CLEAN_DIR / "labels.csv", index=False)
    print(f"  Saved labels.csv ({len(df)} labels)")
    print("═══ Labels transform complete ═══\n")


if __name__ == "__main__":
    run()
