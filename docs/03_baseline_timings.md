# Checkpoint 2 (CP2) — Baseline Performance Timings

## Environment & Benchmarking Setup

- **Database:** `uber_ride_hailing` (schema: `uber`)
- **DBMS:** PostgreSQL 18.6 (Postgres.app; macOS, Darwin 27.2, ARM64)
- **Client:** `psql` 16.15 (Homebrew)
- **Workload:** `queries/workload_30.sql` (25 READ queries R01–R25, 5 WRITE queries W01–W05)
- **Command:** `bash benchmarks/run_benchmark.sh uber_ride_hailing baseline`
- **Methodology:** Each query was run three times with `EXPLAIN (ANALYZE, BUFFERS)`. Each WRITE query ran in a `BEGIN` / `ROLLBACK` transaction so the data remained unchanged.
- **Data:** 300,000 rows in `uber.trips` at verification; eight tables in the schema.
- **Schema state:** Primary-key and unique-constraint indexes only; no performance indexes had been added for the baseline.
- **Raw plans and summary:** `benchmarks/results/baseline/` contains `R01.txt`–`R25.txt`, `W01.txt`–`W05.txt`, and `summary.csv`.
- **Benchmark date:** 18 November 2026. Host CPU count, memory, storage details, and PostgreSQL configuration were not recorded.

## Baseline Execution Timings (30 Workload Queries)

All timing values are in milliseconds. The Average column is the arithmetic mean of the three `Execution Time` values in the corresponding raw plan file, rounded to three decimal places. Scan Type lists the scan nodes shown in the first raw run; some plans use parallel workers or multiple scan nodes.

| Query ID | READ/WRITE | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan Type | Explanation of Performance |
|---|---|---:|---:|---:|---:|---|---|
| R01 | READ | 68.027 | 8.397 | 6.084 | 27.503 | Parallel Seq Scan on trips | Filters all 300,000 trips for one rider and sorts the matches by requested time. The first run read many blocks from storage; later runs were much faster with cache hits. |
| R02 | READ | 11.015 | 8.280 | 9.720 | 9.672 | Parallel Seq Scan on trips | The date function on `requested_at` prevents a plain timestamp index lookup; PostgreSQL checks driver, status, and date conditions while scanning trips. |
| R03 | READ | 8.227 | 6.484 | 6.268 | 6.993 | Seq Scan on riders | `lower(email)` has no matching expression index, so the plan checks all 30,000 riders to find the case-insensitive email match. |
| R04 | READ | 6.826 | 10.894 | 6.867 | 8.196 | Parallel Seq Scan on trips; Seq Scan on cities | The city lookup scans only the small cities table, but trips is scanned to filter the one-day timestamp range before the join and ordering. |
| R05 | READ | 12.971 | 11.599 | 11.470 | 12.013 | Parallel Seq Scan on trips | Checks all trips for the three active statuses, then sorts qualifying rows by requested time to return the oldest 50. |
| R06 | READ | 11.542 | 9.655 | 9.316 | 10.171 | Parallel Seq Scan on trips; Seq Scan on cities | Scans trips for completed records in June, joins the small cities table, then aggregates counts by city. |
| R07 | READ | 11.469 | 12.521 | 10.591 | 11.527 | Parallel Seq Scan on trips; Seq Scan on drivers; Seq Scan on cities | Scans trips for completed Q1 records, joins the driver and city tables, then groups and sorts driver earnings for the top 10. |
| R08 | READ | 34.253 | 27.583 | 28.415 | 30.084 | Parallel Seq Scan on payments | Scans payments and evaluates `EXTRACT(YEAR FROM paid_at)` plus payment status before grouping successful amounts by month and method. |
| R09 | READ | 18.090 | 17.978 | 17.828 | 17.965 | Seq Scan on riders; Seq Scan on trips | Builds a hashed `NOT IN` set by scanning recent trips, and scans riders to find Bengaluru riders absent from that set. |
| R10 | READ | 12.236 | 12.164 | 12.440 | 12.280 | Seq Scan on drivers; Seq Scan on trips | Builds a hashed `NOT IN` set by scanning trips since the cutoff, then scans all drivers and filters for active drivers absent from the set. |
| R11 | READ | 54.305 | 28.253 | 28.801 | 37.120 | Parallel Seq Scan on ratings; Parallel Seq Scan on trips | Scans rider ratings and trips for the join, aggregates ratings by driver, filters groups with fewer than 20 ratings, and sorts the rest. The first run is notably slower than the later runs. |
| R12 | READ | 32.066 | 31.119 | 32.673 | 31.953 | Seq Scan on trips; Seq Scan on cities | Scans all trips and the small cities table; the query extracts the hour and aggregates surge for Delhi. |
| R13 | READ | 9.369 | 9.341 | 9.119 | 9.276 | Seq Scan on riders | The leading-wildcard `ILIKE '%sharma%'` condition does not match a standard B-tree index, so all riders are checked before sorting up to 50 matches. |
| R14 | READ | 0.555 | 0.033 | 0.034 | 0.207 | Index Scan using vehicles_registration_no_key on vehicles; Index Scan using drivers_pkey on drivers | The unique registration-number index locates the vehicle, and the driver primary key resolves its matching driver. The first run includes cache variation. |
| R15 | READ | 5.177 | 4.642 | 4.856 | 4.892 | Index Scan using trips_pkey on trips; Index Scan using riders_pkey on riders; Index Scan using drivers_pkey on drivers; Index Scan using vehicles_pkey on vehicles; Parallel Seq Scan on payments | Primary-key indexes resolve the trip, rider, driver, and vehicle, but payments has no index on `trip_id`, so the left join scans payments. |
| R16 | READ | 21.716 | 21.966 | 21.367 | 21.683 | Index Scan Backward using trips_pkey on trips | The primary-key index provides descending trip order, but `OFFSET 200000` requires walking past roughly 200,000 entries before returning 25 rows. |
| R17 | READ | 23.465 | 31.885 | 23.264 | 26.205 | Seq Scan on trips; Seq Scan on cities | Scans trips and cities to group all requests by city, count cancellations, and order the cancellation rates. |
| R18 | READ | 18550.463 | 18338.087 | 18803.346 | 18563.965 | Seq Scan on riders; correlated Seq Scan on trips | For each of 2,400 Pune riders, a correlated aggregate scans the 300,000-row trips table. The plan records about 13.5 million shared-buffer hits overall. |
| R19 | READ | 10.976 | 10.552 | 10.659 | 10.729 | Parallel Seq Scan on trips; Seq Scan on drivers | Scans trips for completed May records, joins drivers, and aggregates by driver and city before ranking the grouped results. |
| R20 | READ | 13.275 | 13.931 | 13.232 | 13.479 | Parallel Seq Scan on trips | Casting `requested_at` to date in the filter prevents a plain timestamp range lookup; the plan scans trips and filters by completed status and May dates. |
| R21 | READ | 19.666 | 19.522 | 19.632 | 19.607 | Seq Scan on trips; Seq Scan on promo_codes | Reads all trips to count promo usage and left joins the small promo-code table, including codes with no matching trips. |
| R22 | READ | 7.187 | 6.590 | 6.003 | 6.593 | Parallel Seq Scan on payments; Index Scan using trips_pkey on trips; Index Scan using riders_pkey on riders | Scans payments to find failed recent payments; primary-key lookups then resolve each trip and rider. |
| R23 | READ | 51.848 | 52.282 | 50.998 | 51.709 | Seq Scan on trips | Scans trips from 2026 onward and sorts qualifying rows by city, month, and rider for distinct-rider aggregation; the sort spills to temporary buffers. |
| R24 | READ | 11.629 | 11.348 | 12.335 | 11.771 | Parallel Seq Scan on trips | Checks completed trips for either long-distance or long-duration conditions, then sorts matches by fare to return the top 100. |
| R25 | READ | 16.807 | 16.066 | 16.403 | 16.425 | Parallel Seq Scan on trips | Scans completed trips and evaluates the fare-per-kilometre expression for each candidate, then sorts qualifying trips by the computed ratio. |
| W01 | WRITE | 2.509 | 1.370 | 0.549 | 1.476 | No scan | Single-row trip insert; no scan node is needed. The plan runs foreign-key checks for rider, driver, vehicle, city, and promo code. |
| W02 | WRITE | 26.282 | 25.474 | 26.638 | 26.131 | Index Scan using trips_pkey on trips (selection and update) | The primary-key index finds the minimum trip ID, but the status filter rejects 299,701 earlier entries before it finds the oldest ongoing trip; the selected row is then updated by primary key. |
| W03 | WRITE | 5.953 | 3.672 | 3.221 | 4.282 | Seq Scan on drivers | Scans 3,000 drivers for active status and rating below 3.5, then updates 389 matching rows. |
| W04 | WRITE | 149.895 | 30.331 | 29.194 | 69.807 | No scan | Generates 5,000 input rows without scanning a table. Foreign-key triggers run for every inserted trip; trigger and total times vary substantially between runs. |
| W05 | WRITE | 15035.175 | 15130.304 | 15047.977 | 15071.152 | Seq Scan on trips | Scans all trips and selects 3,165 old cancelled rows. The `payments_trip_id_fkey` trigger takes about 15 seconds across those rows because payments has no index on `trip_id`; the transaction is rolled back. |

## Key Baseline Observations

- **Primary-key and unique-key lookups are already efficient:** R14 resolves its registration and driver through existing unique and primary-key indexes. R15 also uses primary-key lookups for the main trip, rider, driver, and vehicle, although its payments join still scans payments.
- **Foreign-key columns are not automatically indexed on the referencing table:** R15 scans payments to match a trip, and W05 spends about 15 seconds in `payments_trip_id_fkey` checks. The schema's `ratings_pkey (trip_id, rated_by)` already supports ratings lookups by trip ID.
- **R18 is the dominant read bottleneck:** Its correlated trips scan runs 2,400 times over a 300,000-row table, averaging 18,563.965 ms.
- **W05 is the dominant write bottleneck:** It finds 3,165 delete candidates with a full trips scan, then spends most execution time checking payments references. The benchmark rolls the deletion back.
- **Date functions and broad filters limit index use:** R02 and R20 apply date operations to `requested_at`; R08 extracts the year from `paid_at`. Numerous aggregation, ranking, and substring-search queries process a large fraction of their tables, so sequential scans are expected in the recorded plans.
- **Timings vary with cache state:** R01 ranged from 68.027 ms to 6.084 ms, and R11 also had a much slower first run. The averages are calculated from the actual three plan times and should be compared using the same run count and environment.
