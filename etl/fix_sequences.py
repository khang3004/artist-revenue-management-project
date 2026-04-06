import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from load.loader import execute_sql

# Reset sequences to MAX(id)
execute_sql("SELECT setval('labels_label_id_seq', (SELECT MAX(label_id) FROM labels));")
execute_sql("SELECT setval('artists_artist_id_seq', (SELECT MAX(artist_id) FROM artists));")
execute_sql("SELECT setval('albums_album_id_seq', (SELECT MAX(album_id) FROM albums));")
execute_sql("SELECT setval('tracks_track_id_seq', (SELECT MAX(track_id) FROM tracks));")

print("Sequences reset!")
