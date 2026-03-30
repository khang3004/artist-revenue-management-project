"""
Transform Step 3b: Merge Apple Music Data
Extracts local tracks from Apple Music XML and merges them into
artists.csv, albums.csv, tracks.csv.

Output → data_lake/clean/{artists,albums,tracks}.csv
"""

import os
import sys
import plistlib
import pandas as pd
import uuid
import re

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import RAW_DIR, CLEAN_DIR

def run():
    print("═══ Transform: Apple Music Library ═══")

    xml_path = RAW_DIR / "apple_music" / "apple_music_Library.xml"
    if not xml_path.exists():
        print("  ⚠ apple_music_Library.xml not found")
        return

    # Load XML
    with open(xml_path, "rb") as f:
        pl = plistlib.load(f)
    
    am_tracks = pl.get("Tracks", {})
    print(f"  Parsed {len(am_tracks)} tracks from Apple Music XML")

    # Load existing CSVs
    art_path = CLEAN_DIR / "artists.csv"
    alb_path = CLEAN_DIR / "albums.csv"
    trk_path = CLEAN_DIR / "tracks.csv"

    df_artists = pd.read_csv(art_path) if art_path.exists() else pd.DataFrame()
    df_albums = pd.read_csv(alb_path) if alb_path.exists() else pd.DataFrame()
    df_tracks = pd.read_csv(trk_path) if trk_path.exists() else pd.DataFrame()

    artists_list = df_artists.to_dict('records') if not df_artists.empty else []
    albums_list = df_albums.to_dict('records') if not df_albums.empty else []
    tracks_list = df_tracks.to_dict('records') if not df_tracks.empty else []

    # Build reference dicts
    artist_map = {} # stage_name.lower() -> mbid
    for a in artists_list:
        sn = str(a.get("stage_name", "")).strip().lower()
        if sn:
            artist_map[sn] = a.get("mbid")

    album_map = {} # (title.lower(), artist_mbid) -> release_mbid
    for a in albums_list:
        t = str(a.get("title", "")).strip().lower()
        aid = a.get("artist_mbid")
        if t and aid:
            album_map[(t, aid)] = a.get("release_mbid")

    track_map = {} # (title.lower(), artist_mbid) -> track_dict
    for idx, t in enumerate(tracks_list):
        ttl = str(t.get("title", "")).strip().lower()
        aid = t.get("artist_mbid")
        if ttl and aid:
            track_map[(ttl, aid)] = t

    added_artists = 0
    added_albums = 0
    added_tracks = 0
    matched_tracks = 0

    def parse_main_artist(raw_str):
        if not raw_str:
            return "Unknown Artist"
        # Split by typical separators
        parts = re.split(r'[,&;]| feat\. | ft\. ', raw_str, flags=re.IGNORECASE)
        # return the first one as main
        return parts[0].strip()

    for track_key, entry in am_tracks.items():
        title = entry.get("Name", "").strip()
        if not title:
            continue

        # Determine Artist
        raw_artist = entry.get("Album Artist")
        if not raw_artist or raw_artist.lower() == "various artists":
            raw_artist = entry.get("Artist")
        
        main_artist = parse_main_artist(raw_artist)
        main_artist_lower = main_artist.lower()

        # 1. Resolve Artist
        if main_artist_lower not in artist_map:
            new_mbid = str(uuid.uuid4())
            artists_list.append({
                "mbid": new_mbid,
                "stage_name": main_artist,
                "full_name": main_artist,
                "artist_type": "solo",
                "debut_date": None,
                "birthday": None,
                "label_name": None,
                "country": None
            })
            artist_map[main_artist_lower] = new_mbid
            added_artists += 1
        
        artist_mbid = artist_map[main_artist_lower]

        # 2. Resolve Album
        album_title = entry.get("Album", "Unknown Album").strip()
        album_title_lower = album_title.lower()
        
        if (album_title_lower, artist_mbid) not in album_map:
            new_release_mbid = str(uuid.uuid4())
            rd = entry.get("Release Date")
            release_date = rd.strftime("%Y-%m-%d") if rd else None
            
            albums_list.append({
                "release_mbid": new_release_mbid,
                "title": album_title,
                "release_date": release_date,
                "artist_mbid": artist_mbid,
                "artist_name": main_artist,
                "label_name": None
            })
            album_map[(album_title_lower, artist_mbid)] = new_release_mbid
            added_albums += 1

        # 3. Resolve Track
        play_count = entry.get("Play Count", 0)
        title_lower = title.lower()

        if (title_lower, artist_mbid) in track_map:
            # Match existing! Update play count
            trk = track_map[(title_lower, artist_mbid)]
            trk["play_count"] = trk.get("play_count", 0) + play_count
            matched_tracks += 1
        else:
            # Create new track
            isrc = f"AM{str(uuid.uuid4()).replace('-', '')[:10].upper()}"
            duration_ms = entry.get("Total Time", 0)
            duration_sec = duration_ms // 1000 if duration_ms else 0
            
            new_trk = {
                "recording_mbid": str(uuid.uuid4()),
                "title": title,
                "isrc": isrc,
                "duration_seconds": duration_sec,
                "artist_mbid": artist_mbid,
                "artist_name": main_artist,
                "play_count": play_count
            }
            tracks_list.append(new_trk)
            track_map[(title_lower, artist_mbid)] = new_trk
            added_tracks += 1

    # Save back to CSVs
    pd.DataFrame(artists_list).to_csv(art_path, index=False)
    pd.DataFrame(albums_list).to_csv(alb_path, index=False)
    pd.DataFrame(tracks_list).to_csv(trk_path, index=False)

    print(f"  Added {added_artists} new artists")
    print(f"  Added {added_albums} new albums")
    print(f"  Added {added_tracks} new tracks")
    print(f"  Updated {matched_tracks} matched tracks with Apple Music streams")
    print("═══ Apple Music Library merge complete ═══\n")


if __name__ == "__main__":
    run()
