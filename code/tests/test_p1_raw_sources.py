"""Read-only provenance and P1 input checks; no cleaning, features or sampling."""
import csv
from decimal import Decimal
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data/raw"
manifest = json.loads((RAW / "tidytuesday_2022-01-25_manifest.json").read_text())
COMMIT = "84c6abbadd5a038b99ca01da5aa377a07c8b46a7"
assert manifest["upstream_commit"] == COMMIT


def read(path):
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


tables = {}
for item in manifest["files"]:
    raw = (RAW / item["file"]).read_bytes()
    assert len(raw) == item["size_bytes"]
    assert hashlib.md5(raw).hexdigest() == item["md5"]
    assert hashlib.sha256(raw).hexdigest() == item["sha256"]
    blob = hashlib.sha1(f"blob {len(raw)}\0".encode() + raw).hexdigest()
    assert blob == item["git_blob_sha1"]
    assert item["source_url"] == (
        f"https://raw.githubusercontent.com/rfordatascience/tidytuesday/{COMMIT}"
        f"/data/2022/2022-01-25/{item['file']}"
    )
    rows = read(RAW / item["file"])
    assert len(rows) == item["rows"]
    assert list(rows[0]) == item["column_names"]
    assert len(rows[0]) == item["columns"]
    assert all(None not in row and all(v is not None for v in row.values()) for row in rows)
    keyed = {row["id"]: row for row in rows}
    assert len(keyed) == len(rows) and "" not in keyed
    tables[item["file"]] = keyed

details, ratings = tables["details.csv"], tables["ratings.csv"]
assert len(details) == 21631 and len(ratings) == 21831
clean = read(ROOT / "data_clean.csv")
assert len(clean) == 21631 and len(clean[0]) == 83
assert {row["id"] for row in clean} == details.keys() & ratings.keys()


def number(value):
    return None if value in ("", "NA") else Decimal(value)


# Compare existing records by ID. No join output or sample is generated.
for filename, expected in (("data_clean.csv", 21631), ("dev_subsample.csv", 6489),
                           ("comparison_sample.csv", 3244)):
    rows = clean if filename == "data_clean.csv" else read(ROOT / filename)
    assert len(rows) == expected and len({row["id"] for row in rows}) == expected
    for row in rows:
        ident = row["id"]
        assert ident in details and ident in ratings
        for field in ("average", "users_rated", "bayes_average", "rank", "year"):
            assert number(row[field]) == number(ratings[ident][field]), (filename, ident, field)
        for field in ("owned", "trading", "wanting", "wishing"):
            assert number(row[field]) == number(details[ident][field]), (filename, ident, field)

# Reconcile source counts documented in P1's preserved 22 November notes.
invalid_years = sum(number(row["yearpublished"]) is None or
                    not 1900 <= number(row["yearpublished"]) <= 2022
                    for row in details.values())
zeros = {field: sum(number(row[field]) == 0 for row in details.values())
         for field in ("minplayers", "maxplayers", "playingtime", "minage")}
assert invalid_years == 302
assert zeros == {"minplayers": 44, "maxplayers": 164, "playingtime": 774, "minage": 1301}
print("PASS: pinned upstream bytes/checksums/schema; 21,631 shared game IDs; "
      "nine unchanged fields agree in full/development/holdout data; "
      "P1's documented invalid-year and zero counts agree. No pipeline executed.")
