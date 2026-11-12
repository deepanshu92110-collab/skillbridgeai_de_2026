-- Load the supplied seed CSVs into the tables created by sql/01_schema.sql.
-- Run this from the repository root with psql connected to the target database.
\set ON_ERROR_STOP on
SET search_path TO uber;

-- Parents first
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy riders FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true)
\copy drivers FROM 'seed_data/drivers.csv' WITH (FORMAT csv, HEADER true)
\copy vehicles FROM 'seed_data/vehicles.csv' WITH (FORMAT csv, HEADER true)
\copy promo_codes FROM 'seed_data/promo_codes.csv' WITH (FORMAT csv, HEADER true)

-- Trips reference riders, drivers, vehicles, cities, and optional promo codes.
\copy trips FROM 'seed_data/trips.csv' WITH (FORMAT csv, HEADER true)

-- Child records reference trips.
\copy payments FROM 'seed_data/payments.csv' WITH (FORMAT csv, HEADER true)
\copy ratings FROM 'seed_data/ratings.csv' WITH (FORMAT csv, HEADER true)

-- Compare actual rows with the expected seed file counts.
SELECT 'cities' AS table_name, count(*) AS actual_rows, 10 AS expected_rows,
       count(*) = 10 AS matches_expected FROM cities
UNION ALL
SELECT 'riders', count(*), 30000, count(*) = 30000 FROM riders
UNION ALL
SELECT 'drivers', count(*), 3000, count(*) = 3000 FROM drivers
UNION ALL
SELECT 'vehicles', count(*), 3300, count(*) = 3300 FROM vehicles
UNION ALL
SELECT 'promo_codes', count(*), 40, count(*) = 40 FROM promo_codes
UNION ALL
SELECT 'trips', count(*), 300000, count(*) = 300000 FROM trips
UNION ALL
SELECT 'payments', count(*), 245839, count(*) = 245839 FROM payments
UNION ALL
SELECT 'ratings', count(*), 307214, count(*) = 307214 FROM ratings;

ANALYZE;
