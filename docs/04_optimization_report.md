# CP3 Query Optimization Report

## Scope and outcome

CP3 adds plan-driven indexes and optimized query variants for the 25 read and 5 write statements in `queries/workload_30.sql`. The optimized workload was run three times per statement with `EXPLAIN (ANALYZE, BUFFERS)`. Write statements were each executed inside `BEGIN`/`ROLLBACK`, following `benchmarks/run_benchmark.sh`.

The benchmark results below are observed values from this run. Improvement is calculated as `(baseline average - optimized average) / baseline average * 100`; a negative value is a regression. Values are rounded to two decimal places. Baseline values are from the recorded baseline summary; optimized values are from `benchmarks/results/optimized/summary.csv`.

## Indexes created

All indexes are ordinary PostgreSQL B-tree indexes unless otherwise noted. Existing primary-key and unique-constraint indexes were left intact.

| Index | Definition and purpose |
|---|---|
| `trips_rider_requested_at_idx` | `(rider_id, requested_at DESC)` supports R01 rider history and R18's per-rider newest-trip lookup. |
| `trips_driver_requested_at_idx` | `(driver_id, requested_at DESC)` supports driver/time matching, including R10's correlated `NOT IN` subquery, and driver joins in R07/R19. |
| `trips_requested_at_city_idx` | `(requested_at, city_id)` supports general timestamp windows such as R04 and R09/R10/R23. |
| `trips_completed_requested_at_idx` | Partial index on `(requested_at, driver_id, city_id) WHERE status = 'COMPLETED'`; its date-leading key supports completed-trip ranges and aggregation in R06/R07/R19/R20. |
| `trips_completed_driver_requested_at_idx` | Partial index on `(driver_id, requested_at) WHERE status = 'COMPLETED'`; the driver-leading order supports R02's driver equality followed by its date range. It has a distinct access pattern from the date-leading completed index. |
| `trips_dispatch_requested_at_idx` | Partial index on `requested_at` for `REQUESTED`, `ACCEPTED`, and `ONGOING` trips supports R05's oldest dispatch queue. |
| `trips_ongoing_trip_id_idx` | Partial index on `trip_id WHERE status = 'ONGOING'` supports W02's minimum ongoing trip lookup. It is a status-specific subset, not a duplicate of the full trips primary key. |
| `trips_cancelled_requested_at_idx` | Partial index on `requested_at WHERE status LIKE 'CANCELLED%'` matches W05's status predicate and supports finding old cancelled trips. Keeping the predicate aligned with the query allows PostgreSQL to recognize the partial index as applicable. |
| `payments_trip_id_idx` | Indexes the referencing side of `payments_trip_id_fkey`; supports trip-to-payment joins and the foreign-key check triggered when W05 deletes trips. |
| `riders_lower_email_idx` | Expression index on `lower(email)` supports R03; the existing unique index on raw `email` cannot serve the lower-case expression. |
| `payments_status_paid_at_idx` | `(payment_status, paid_at)` supports R08 and R22's payment status and time filters. |

The schema's `ratings_pkey (trip_id, rated_by)` already has `trip_id` as its leading column, so it was not duplicated. Existing primary-key/unique indexes also serve R14–R16 and the trip/rider lookups in R22.

## Query changes and correctness

- **R02, R04, R06, R07, R19, R22, R23, and W05** express date windows as timestamp ranges instead of applying a date cast or relying on a cast at the indexed column. Where the original used a bare date string against a `timestamptz`, the rewrite constructs midnight in the current session time zone. R02 and R20 preserve `DATE(timestamptz)`'s session-time-zone boundaries; R08 likewise preserves `EXTRACT(YEAR FROM timestamptz)`'s session-time-zone year.
- **R08** uses a half-open interval from the start of 2026 to the start of 2027. This retains all instants whose session-local year is 2026 and excludes the next year's boundary.
- **R09** uses `NOT EXISTS` for the anti-join. It is equivalent to the original `NOT IN` under this schema because `trips.rider_id` is declared `NOT NULL`.
- **R10** retains `NOT IN`, including its NULL behavior, because `trips.driver_id` is nullable. Replacing it with `NOT EXISTS` changes results if the subquery returns a NULL driver ID. This preserves the original statement's exact three-valued logic.
- **R18** replaces `max(requested_at)` with descending timestamp order and `LIMIT 1`. `requested_at` is `NOT NULL`, so the returned timestamp (or NULL when there is no trip) is the same. The rider/time index supports this lookup.
- **R19** uses valid PostgreSQL window syntax, `ORDER BY count(*) DESC`.
- **W01–W04** preserve the original insert/update expressions. **W05** retains its delete predicate and rollback behavior; its range boundary is expressed in the session time zone.

Other statements retain their original query logic. Their supporting access paths come from the indexes or existing constraints; some plans still favor sequential scans because those statements process broad portions of a table.

## Before/after timings

Times are milliseconds and are averages of three executions. Percentage is improvement when positive and regression when negative.

| Query | Baseline avg (ms) | Optimized avg (ms) | Improvement / (regression) |
|---|---:|---:|---:|
| R01 | 27.503 | 0.064 | 99.77% |
| R02 | 9.672 | 0.167 | 98.27% |
| R03 | 6.993 | 0.039 | 99.44% |
| R04 | 8.196 | 0.124 | 98.49% |
| R05 | 12.013 | 0.171 | 98.58% |
| R06 | 10.171 | 2.492 | 75.50% |
| R07 | 11.527 | 4.735 | 58.92% |
| R08 | 30.084 | 22.810 | 24.18% |
| R09 | 17.965 | 6.152 | 65.76% |
| R10 | 12.280 | 0.815 | 93.36% |
| R11 | 37.120 | 43.364 | -16.82% |
| R12 | 31.953 | 29.921 | 6.36% |
| R13 | 9.276 | 9.029 | 2.66% |
| R14 | 0.207 | 0.034 | 83.57% |
| R15 | 4.892 | 0.158 | 96.77% |
| R16 | 21.683 | 23.463 | -8.21% |
| R17 | 26.205 | 23.533 | 10.20% |
| R18 | 18563.965 | 4.568 | 99.98% |
| R19 | 10.729 | 3.233 | 69.87% |
| R20 | 13.479 | 2.870 | 78.71% |
| R21 | 19.607 | 18.268 | 6.83% |
| R22 | 6.593 | 0.815 | 87.64% |
| R23 | 51.709 | 42.825 | 17.18% |
| R24 | 11.771 | 11.409 | 3.08% |
| R25 | 16.425 | 17.003 | -3.52% |
| W01 | 1.476 | 1.286 | 12.87% |
| W02 | 26.131 | 0.541 | 97.93% |
| W03 | 4.282 | 2.838 | 33.72% |
| W04 | 69.807 | 45.928 | 34.21% |
| W05 | 15071.152 | 11.748 | 99.92% |

## Plan changes and trade-offs

- **R18:** The baseline correlated aggregate scanned `trips` 2,400 times. The optimized plan still performs one lookup per rider, but those lookups use `trips_rider_requested_at_idx` as index-only scans rather than rescanning the whole table.
- **W05:** The baseline delete found 3,165 rows with a sequential scan, and the `payments_trip_id_fkey` trigger dominated execution at roughly 15 seconds. The optimized plan uses `trips_cancelled_requested_at_idx`; the payments foreign-key trigger took about 4.6–4.8 ms per run with `payments_trip_id_idx` present. W05 remains an actual delete inside a transaction and is rolled back after each run.
- **R01/R02/R03/R04/R05/R06/R07/R08/R15/R18/R19/R20/R22/R23, W02, and W05** show new index or bitmap/index-only access in their optimized plans. R10 also obtains the relevant dated trip subset through an index while preserving `NOT IN` semantics.
- **R11, R12, R13, R16, R17, R21, R24, and R25** continue to use sequential scans in at least one significant relation; these queries either aggregate/process broad data or have predicates/orderings not served selectively by the added indexes. R16 still uses the trips primary-key index, but its deep offset remains expensive.
- **R11 regressed 16.82%, R16 8.21%, and R25 3.52% by the measured averages.** Their plans did not gain a clearly selective new access path; run-to-run variation is material for these small differences. R13 and R24 improved only slightly. These results do not support claiming that every query improved.
- The additional indexes consume storage and add work to inserts, updates, and deletes on their indexed columns. This matters especially for W01/W04 inserts and status/timestamp changes. The timing table records the net observed effect for this single run set, not a general guarantee.

## Environment and method

The baseline was recorded on 18 November 2026 using macOS Darwin 27.2, ARM64, PostgreSQL client 16.15 and PostgreSQL server 18.6, database `uber_ride_hailing`, schema `uber`, with 300,000 trips. Baseline host CPU, memory, storage details, and PostgreSQL configuration were not recorded. The optimized run used the repository's `benchmarks/run_benchmark.sh` with `sql/06_optimized_queries.sql` as the workload and phase `optimized`; the same local database was used after applying `sql/05_indexes.sql`.

The runner issued `EXPLAIN (ANALYZE, BUFFERS)` three times for each statement and calculated average, median, minimum, and maximum execution time. It wrapped W01–W05 in `BEGIN`/`ROLLBACK`. All 30 statements produced three execution times and a corresponding raw plan file in `benchmarks/results/optimized/`. The summary averages were checked against the three raw-plan execution times. This is not a controlled statistical study: no reset to a fresh database or cache normalization was performed, and the baseline and optimized runs occurred at different times.

## Limitations

- R10 intentionally preserves `NOT IN` semantics; if a recent trip has a NULL `driver_id`, the original predicate can reject every active driver. This is retained for exact compatibility with the supplied workload.
- The optimized benchmark shows observed plans and timings for this database state. Planner choices and improvements may differ with other data distributions, statistics, cache states, or configuration.
- No additional indexes were added for leading-wildcard R13 or the arithmetic predicate/order in R25. Such indexes would require a different indexing strategy and/or expression-specific design, with additional maintenance cost.
