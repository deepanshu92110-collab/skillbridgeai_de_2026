-- CP3 optimized query set. Labels correspond to queries/workload_30.sql.
-- Run each statement independently with search_path set to uber.
SET search_path TO uber;

-- @R01
SELECT * FROM trips
WHERE rider_id = 1042
ORDER BY requested_at DESC
LIMIT 20;

-- @R02
-- Retain DATE(timestamptz)'s session-time-zone day boundaries.
SELECT driver_id, count(*) AS trips, sum(fare_amount) AS earnings
FROM trips
WHERE driver_id = 217
  AND status = 'COMPLETED'
  AND requested_at >= (TIMESTAMP '2026-03-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  AND requested_at <  (TIMESTAMP '2026-04-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
GROUP BY driver_id;

-- @R03
SELECT rider_id, full_name, home_city_id
FROM riders
WHERE lower(email) = 'karan.verma1042@mail.com';

-- @R04
SELECT t.trip_id, t.status, t.requested_at, t.fare_amount
FROM trips t
JOIN cities c ON c.city_id = t.city_id
WHERE c.city_name = 'Bengaluru'
  AND t.requested_at >= (TIMESTAMP '2026-05-10 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  AND t.requested_at <  (TIMESTAMP '2026-05-11 00:00:00' AT TIME ZONE current_setting('TimeZone'))
ORDER BY t.requested_at;

-- @R05
SELECT trip_id, city_id, status, requested_at
FROM trips
WHERE status IN ('REQUESTED', 'ACCEPTED', 'ONGOING')
ORDER BY requested_at
LIMIT 50;

-- @R06
SELECT c.city_name, count(*) AS completed_trips
FROM trips t
JOIN cities c ON c.city_id = t.city_id
WHERE t.status = 'COMPLETED'
  AND t.requested_at >= (TIMESTAMP '2026-06-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  AND t.requested_at <  (TIMESTAMP '2026-07-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
GROUP BY c.city_name
ORDER BY completed_trips DESC;

-- @R07
SELECT d.driver_id, d.full_name, count(*) AS trips, sum(t.fare_amount) AS earnings
FROM drivers d
JOIN trips t ON t.driver_id = d.driver_id
JOIN cities c ON c.city_id = d.city_id
WHERE c.city_name = 'Mumbai'
  AND t.status = 'COMPLETED'
  AND t.requested_at >= (TIMESTAMP '2026-01-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  AND t.requested_at <  (TIMESTAMP '2026-04-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
GROUP BY d.driver_id, d.full_name
ORDER BY earnings DESC
LIMIT 10;

-- @R08
-- The year interval is evaluated in the session time zone, as EXTRACT was.
SELECT date_trunc('month', paid_at) AS month, method,
       count(*) AS payments, sum(amount) AS revenue
FROM payments
WHERE payment_status = 'SUCCESS'
  AND paid_at >= (TIMESTAMP '2026-01-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  AND paid_at <  (TIMESTAMP '2027-01-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R09
-- rider_id is NOT NULL in trips; NOT EXISTS expresses anti-join intent.
SELECT r.rider_id, r.full_name, r.email
FROM riders r
WHERE r.home_city_id = 1
  AND NOT EXISTS (
      SELECT 1 FROM trips t
      WHERE t.rider_id = r.rider_id
        AND t.requested_at >= (TIMESTAMP '2026-04-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  );

-- @R10
-- Preserve the original NOT IN semantics, including NULL behavior.
SELECT d.driver_id, d.full_name, d.city_id
FROM drivers d
WHERE d.status = 'ACTIVE'
  AND d.driver_id NOT IN (
      SELECT t.driver_id FROM trips t
      WHERE t.requested_at >= (TIMESTAMP '2026-06-25 00:00:00' AT TIME ZONE current_setting('TimeZone'))
  );

-- @R11
SELECT t.driver_id, round(avg(r.stars), 2) AS avg_stars, count(*) AS ratings
FROM ratings r
JOIN trips t ON t.trip_id = r.trip_id
WHERE r.rated_by = 'RIDER'
GROUP BY t.driver_id
HAVING count(*) >= 20
ORDER BY avg_stars ASC
LIMIT 20;

-- @R12
SELECT EXTRACT(HOUR FROM t.requested_at) AS hour_of_day,
       round(avg(t.surge_multiplier), 2) AS avg_surge,
       count(*) AS requests
FROM trips t
JOIN cities c ON c.city_id = t.city_id
WHERE c.city_name = 'Delhi'
GROUP BY 1
ORDER BY 1;

-- @R13
SELECT rider_id, full_name, phone
FROM riders
WHERE full_name ILIKE '%sharma%'
ORDER BY full_name
LIMIT 50;

-- @R14
SELECT v.vehicle_id, v.registration_no, v.make, v.model,
       d.driver_id, d.full_name, d.phone
FROM vehicles v
JOIN drivers d ON d.driver_id = v.driver_id
WHERE v.registration_no = 'KA01AA1500';

-- @R15
SELECT t.trip_id, t.requested_at, t.dropoff_at, t.distance_km, t.fare_amount,
       r.full_name AS rider, d.full_name AS driver, v.registration_no,
       p.method, p.payment_status
FROM trips t
JOIN riders r ON r.rider_id = t.rider_id
JOIN drivers d ON d.driver_id = t.driver_id
JOIN vehicles v ON v.vehicle_id = t.vehicle_id
LEFT JOIN payments p ON p.trip_id = t.trip_id
WHERE t.trip_id = 123458;

-- @R16
SELECT trip_id, rider_id, driver_id, city_id, status, fare_amount, requested_at
FROM trips
ORDER BY trip_id DESC
OFFSET 200000
LIMIT 25;

-- @R17
SELECT c.city_name,
       count(*) AS requests,
       count(*) FILTER (WHERE t.status LIKE 'CANCELLED%') AS cancelled,
       round(100.0 * count(*) FILTER (WHERE t.status LIKE 'CANCELLED%') / count(*), 2) AS cancel_pct
FROM trips t
JOIN cities c ON c.city_id = t.city_id
GROUP BY c.city_name
ORDER BY cancel_pct DESC;

-- @R18
-- Ordered index lookup returns the maximum timestamp without rescanning trips.
SELECT r.rider_id, r.full_name,
       (SELECT t.requested_at
        FROM trips t
        WHERE t.rider_id = r.rider_id
        ORDER BY t.requested_at DESC
        LIMIT 1) AS last_trip_at
FROM riders r
WHERE r.home_city_id = 6
ORDER BY last_trip_at DESC NULLS LAST;

-- @R19
SELECT *
FROM (
    SELECT d.city_id, d.driver_id, d.full_name, count(*) AS trips,
           RANK() OVER (
               PARTITION BY d.city_id
               ORDER BY count(*) DESC
           ) AS city_rank
    FROM drivers d
    JOIN trips t ON t.driver_id = d.driver_id
    WHERE t.status = 'COMPLETED'
      AND t.requested_at >= (TIMESTAMP '2026-05-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
      AND t.requested_at <  (TIMESTAMP '2026-06-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
    GROUP BY d.city_id, d.driver_id, d.full_name
) ranked
WHERE city_rank <= 3
ORDER BY city_id, city_rank;

-- @R20
-- Preserve DATE(timestamptz) session-time-zone semantics with a half-open range.
SELECT day, revenue, sum(revenue) OVER (ORDER BY day) AS running_total
FROM (
    SELECT requested_at::date AS day, sum(fare_amount) AS revenue
    FROM trips
    WHERE status = 'COMPLETED'
      AND requested_at >= (TIMESTAMP '2026-05-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
      AND requested_at <  (TIMESTAMP '2026-06-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
    GROUP BY 1
) daily
ORDER BY day;

-- @R21
SELECT p.promo_code, p.discount_pct, count(t.trip_id) AS trips_used
FROM promo_codes p
LEFT JOIN trips t ON t.promo_code = p.promo_code
GROUP BY p.promo_code, p.discount_pct
ORDER BY trips_used DESC;

-- @R22
SELECT p.payment_id, p.amount, p.paid_at, r.rider_id, r.phone
FROM payments p
JOIN trips t ON t.trip_id = p.trip_id
JOIN riders r ON r.rider_id = t.rider_id
WHERE p.payment_status = 'FAILED'
  AND p.paid_at >= (TIMESTAMP '2026-06-24 00:00:00' AT TIME ZONE current_setting('TimeZone'))
ORDER BY p.paid_at DESC;

-- @R23
SELECT city_id, date_trunc('month', requested_at) AS month,
       count(DISTINCT rider_id) AS active_riders
FROM trips
WHERE requested_at >= (TIMESTAMP '2026-01-01 00:00:00' AT TIME ZONE current_setting('TimeZone'))
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R24
SELECT trip_id, driver_id, distance_km, duration_min, fare_amount
FROM trips
WHERE status = 'COMPLETED'
  AND (distance_km > 43 OR duration_min > 150)
ORDER BY fare_amount DESC
LIMIT 100;

-- @R25
SELECT trip_id, city_id, distance_km, fare_amount,
       round(fare_amount / NULLIF(distance_km, 0), 2) AS fare_per_km
FROM trips
WHERE status = 'COMPLETED'
  AND fare_amount / NULLIF(distance_km, 0) > 100
ORDER BY fare_per_km DESC
LIMIT 50;

-- @W01
INSERT INTO trips (trip_id, rider_id, city_id, requested_at, pickup_lat, pickup_lng,
                   drop_lat, drop_lng, surge_multiplier, status)
VALUES (90000001, 1042, 6, '2026-07-01 09:15:00+05:30', 18.520400, 73.856700,
        18.559000, 73.807700, 1.40, 'REQUESTED');

-- @W02
UPDATE trips
SET status = 'COMPLETED',
    dropoff_at = pickup_at + interval '27 minutes',
    distance_km = 9.80,
    duration_min = 27,
    fare_amount = 245.50
WHERE trip_id = (SELECT min(trip_id) FROM trips WHERE status = 'ONGOING');

-- @W03
UPDATE drivers
SET status = 'SUSPENDED'
WHERE status = 'ACTIVE' AND driver_rating < 3.5;

-- @W04
INSERT INTO trips (trip_id, rider_id, city_id, requested_at, pickup_lat, pickup_lng,
                   drop_lat, drop_lng, surge_multiplier, status)
SELECT 90001000 + g, 1 + (g * 7) % 30000, 1,
       TIMESTAMPTZ '2026-07-01 10:00:00+05:30' + g * interval '2 seconds',
       12.971600, 77.594600, 12.935200, 77.624500, 1.00, 'REQUESTED'
FROM generate_series(1, 5000) AS g;

-- @W05
DELETE FROM trips
WHERE status LIKE 'CANCELLED%'
  AND requested_at < (TIMESTAMP '2025-02-01 00:00:00' AT TIME ZONE current_setting('TimeZone'));
