# Frozen historical rating-SD source

[historical_games.csv](historical_games.csv) is a byte-for-byte copy recovered from the owner's original `P5_external_SD/source_cache/historical_games.csv`. P5 Scripts 01, 04 and 11 record its upstream source as [AgeOfWar's games.csv](https://raw.githubusercontent.com/AgeOfWar/AgeOfWar.github.io/master/games.csv). This is the recovered cache, not a fresh download of that mutable URL.

| Property | Recovered file |
| --- | --- |
| Size | 22,119,464 bytes (21.09 MiB) |
| MD5 | `f5c23231f6c17937569dce304626d3c4` |
| SHA-256 | `a3e7d53f1b0626f90c9d59bd016a125b9435ba7211c0ed1d9fffe96a518efb4c` |
| Shape | 21,925 game records, 48 columns; unique `BGGId` |
| Relevant fields | `BGGId`, `StdDev`, `NumUserRatings`, `AvgRating` |

`StdDev` is the historical within-game SD of individual ratings, not the standard error of an average. Read-only reconciliation against committed artifacts confirms the same ordered 6,416-game development lookup (including SD, rating count and historical mean), 3,209-game holdout match and 21,375 usable matches in the 21,631-game full-data audit. Numeric comparisons use tolerance `1e-12`. The checks establish consistency with the saved analysis, not the original snapshot's collection date or independently verified upstream provenance. The date remains unverified, and the SD remains a fixed plug-in assumption.

The file-specific `-text` Git attribute prevents line-ending conversion. Do not reserialize this source or replace it with today's upstream file. The four shared P1 data CSVs remain at the repository root.

Scripts prefer the original `P5_external_SD/source_cache/` cache (including an explicit `P5_CACHE_DIR`), then the legacy flat launch-directory copy, then this committed file. No live historical-source download is used. See the [reproduction guide](../../docs/REPRODUCTION.md) and [source validation test](../../code/tests/test_historical_source.R) for read-only commands and remaining reproduction limitations.
