# Baseline Benchmark Timings

## Purpose

This benchmark records the unoptimized query workload as a reference for later indexing and query optimization. It runs each supplied query with `EXPLAIN (ANALYZE, BUFFERS)` three times. Write queries run in transactions that are rolled back.

## Environment and database

- Benchmark date: 18 November 2026.
- Host: macOS (Darwin 27.2), ARM64. The host model, CPU core count, and memory size were not recorded.
- PostgreSQL client: `psql` 16.15 (Homebrew).
- PostgreSQL server: 18.6 (Postgres.app), 64-bit, compiled with Apple clang 15.0.0.
- Server configuration values and storage details were not recorded.
- Database: `uber_ride_hailing`; benchmark schema: `uber`.
- Data size: 300,000 rows in `uber.trips` at verification. The schema has eight tables.
- Schema state: the baseline schema has its primary-key and unique-constraint indexes; no performance indexes were added for this phase.

## Method

Command run from the project root:

```bash
bash benchmarks/run_benchmark.sh uber_ride_hailing baseline
```

The official workload contains 25 reads (R01–R25) and 5 writes (W01–W05). All 30 queries completed successfully for three runs each. The runner saved every run's raw plan, including execution time and buffer data, and calculated the average from the three `Execution Time` values. Write statements were run as `BEGIN; EXPLAIN (ANALYZE, BUFFERS) ...; ROLLBACK;` by the runner.

## Average execution times

Times are milliseconds, copied from the generated `summary.csv`.

| Query | Type | Average (ms) |
|---|---|---:|
| R01 | READ | 27.503 |
| R02 | READ | 9.672 |
| R03 | READ | 6.993 |
| R04 | READ | 8.196 |
| R05 | READ | 12.013 |
| R06 | READ | 10.171 |
| R07 | READ | 11.527 |
| R08 | READ | 30.084 |
| R09 | READ | 17.965 |
| R10 | READ | 12.280 |
| R11 | READ | 37.120 |
| R12 | READ | 31.953 |
| R13 | READ | 9.276 |
| R14 | READ | 0.207 |
| R15 | READ | 4.892 |
| R16 | READ | 21.683 |
| R17 | READ | 26.205 |
| R18 | READ | 18563.965 |
| R19 | READ | 10.729 |
| R20 | READ | 13.479 |
| R21 | READ | 19.607 |
| R22 | READ | 6.593 |
| R23 | READ | 51.709 |
| R24 | READ | 11.771 |
| R25 | READ | 16.425 |
| W01 | WRITE | 1.476 |
| W02 | WRITE | 26.131 |
| W03 | WRITE | 4.282 |
| W04 | WRITE | 69.807 |
| W05 | WRITE | 15071.152 |

## Plan observations

- Sequential scans appear in 25 query rows; index scans appear in 5. Some queries use both. R14, R15, R16, and R22 use primary-key or unique-key indexes in parts of their plans, while broad filters and aggregations commonly scan tables sequentially.
- R01 scans `trips` sequentially and reads roughly 5,000–5,600 shared blocks per run. Its first run took 68.027 ms; the following runs took 8.397 ms and 6.084 ms, showing substantial run-to-run cache variation.
- R18 is the slowest read at 18,563.965 ms average. Its plan scans `riders` and runs a correlated aggregate over `trips` 2,400 times. Each subplan execution scans the 300,000-row trips table; the plan reports 13,517,176 shared-buffer hits overall.
- W05 is the slowest write at 15,071.152 ms average. It sequentially scans `trips`, identifies 3,165 rows for deletion, and spends most of its time in the `payments_trip_id_fkey` trigger (about 15 seconds in the plans). The delete was rolled back.
- Plans are the database server's observed execution plans; no benchmark-specific memory or cache settings were recorded.

## Conclusion

This baseline is dominated by repeated or broad sequential scans for selected workloads. R18's repeated scan of `trips` and W05's foreign-key checks are the clearest optimization targets. The averages are valid for the recorded run, but cache-sensitive variation—visible in R01—means later comparisons should use the same three-run method and environment.

## Output files

- Summary: `benchmarks/results/baseline/summary.csv` (30 query rows plus header).
- Raw plans: `benchmarks/results/baseline/R01.txt` through `R25.txt` and `W01.txt` through `W05.txt` (three plans per file).
