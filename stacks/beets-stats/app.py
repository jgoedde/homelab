from flask import Flask, jsonify
import sqlite3
from datetime import datetime, timezone
import logging

DB_PATH = "/beets/library.db"
LIMIT = 5

app = Flask(__name__)
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

def get_conn():
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn

def fmt_date(ts):
    if not ts:
        return None
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d")

@app.route("/stats")
def stats():
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("SELECT COUNT(*) AS c FROM albums")
    total_albums = cur.fetchone()["c"]

    cur.execute("SELECT COUNT(*) AS c FROM items")
    total_tracks = cur.fetchone()["c"]

    cur.execute("SELECT COUNT(DISTINCT albumartist) AS c FROM albums")
    total_artists = cur.fetchone()["c"]

    cur.execute("""
        SELECT album, albumartist, added
        FROM albums
        ORDER BY added DESC
        LIMIT ?
    """, (LIMIT,))
    last_albums = [
        {"title": row["album"], "artist": row["albumartist"], "added": fmt_date(row["added"])}
        for row in cur.fetchall()
    ]

    cur.execute("""
        SELECT albumartist, MAX(added) AS added
        FROM albums
        GROUP BY albumartist
        ORDER BY added DESC
        LIMIT ?
    """, (LIMIT,))
    last_artists = [
        {"name": row["albumartist"], "added": fmt_date(row["added"])}
        for row in cur.fetchall()
    ]

    conn.close()
    return jsonify({
        "totals": {"albums": total_albums, "tracks": total_tracks, "artists": total_artists},
        "last_albums": last_albums,
        "last_artists": last_artists,
    })

if __name__ == "__main__":
    logger.info("Starting beets-stats server")
    app.run(host="0.0.0.0", port=5050)
