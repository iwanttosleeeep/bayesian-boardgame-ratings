# Raw source data

The four shared P1 processed CSVs remain at the repository root. Files here are original inputs; adding them did not rerun cleaning, feature engineering, sampling, fitting or figure generation.

## P1 original TidyTuesday inputs

The original [TidyTuesday 2022-01-25 Board Games dataset](https://github.com/rfordatascience/tidytuesday/tree/84c6abbadd5a038b99ca01da5aa377a07c8b46a7/data/2022/2022-01-25) is pinned to upstream commit [`84c6abbadd5a038b99ca01da5aa377a07c8b46a7`](https://github.com/rfordatascience/tidytuesday/commit/84c6abbadd5a038b99ca01da5aa377a07c8b46a7), dated 25 January 2022 (01:39:20 UTC). Both files were retrieved directly from its raw URLs on 27 November 2026 without parsing or reserialization during download. GitHub's file history identifies that original commit as the last change to both files; their blob identities also match the main-branch snapshot inspected during retrieval (`e3bf4a8cdbd4c3b332eb0bd0c51d57a1b284c395`).

| File | Pinned source URL | Bytes | Data rows × columns | MD5 |
| --- | --- | --- | --- | --- |
| [details.csv](details.csv) | [Raw download](https://raw.githubusercontent.com/rfordatascience/tidytuesday/84c6abbadd5a038b99ca01da5aa377a07c8b46a7/data/2022/2022-01-25/details.csv) | 34,332,666 | 21,631 × 23 | `82314a19cabb42830583885aef1718b8` |
| [ratings.csv](ratings.csv) | [Raw download](https://raw.githubusercontent.com/rfordatascience/tidytuesday/84c6abbadd5a038b99ca01da5aa377a07c8b46a7/data/2022/2022-01-25/ratings.csv) | 5,032,959 | 21,831 × 10 | `727ac4df2a4a03bb58e8e6475b325b4e` |

The [machine-readable provenance manifest](tidytuesday_2022-01-25_manifest.json) records the source URLs, commit/date, exact size, MD5, SHA-256, upstream Git blob SHA-1, dimensions and ordered column names. Downloads and staged Git blobs are checked against the upstream blob hashes. File-specific `-text` attributes preserve original bytes, including line endings. These are upstream-byte identities established at retrieval, not previously recorded hashes from P1's local computer.

Read-only validation confirms unique source IDs, 21,631 shared game IDs matching `data_clean.csv`, and zero numeric differences in nine unchanged source fields across the full, development and holdout CSVs: `average`, `users_rated`, `bayes_average`, `rank`, `year`, `owned`, `trading`, `wanting`, `wishing`. The source has P1's documented 302 invalid publication years and zero counts of 44 minimum-player, 164 maximum-player, 774 playing-time and 1,301 minimum-age values. No cleaned table, engineered feature or sample was regenerated. See the [P1 guide](../../docs/P1_DATA_GUIDE.md), [read-only test](../../code/tests/test_p1_raw_sources.py) and [reproduction guide](../../docs/REPRODUCTION.md). Full pipeline reproduction remains untested in this retrieval; local intermediate RDS files remain uncommitted.

## P5 frozen historical rating-SD source

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
