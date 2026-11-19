-- CP3: indexes selected from the recorded baseline plans.
-- Existing primary-key and unique-constraint indexes are not recreated here.
SET search_path TO uber;

-- Rider history and R18's per-rider latest-trip lookup (also usable by R01).
CREATE INDEX trips_rider_requested_at_idx
    ON trips (rider_id, requested_at DESC);

-- Driver-side anti-join and trip-history lookups for R07/R10/R19.
CREATE INDEX trips_driver_requested_at_idx
    ON trips (driver_id, requested_at DESC);

-- R04 and the date-window workload; requested_at is the leading range key.
CREATE INDEX trips_requested_at_city_idx
    ON trips (requested_at, city_id);

-- Completed-trip windows, including R02/R06/R07/R19/R20.
CREATE INDEX trips_completed_requested_at_idx
    ON trips (requested_at, driver_id, city_id)
    WHERE status = 'COMPLETED';

-- R02's single-driver March lookup is more selective with the driver leading.
CREATE INDEX trips_completed_driver_requested_at_idx
    ON trips (driver_id, requested_at)
    WHERE status = 'COMPLETED';

-- R05 oldest active dispatch queue and W02's oldest ongoing-trip lookup.
CREATE INDEX trips_dispatch_requested_at_idx
    ON trips (requested_at)
    WHERE status IN ('REQUESTED', 'ACCEPTED', 'ONGOING');

CREATE INDEX trips_ongoing_trip_id_idx
    ON trips (trip_id)
    WHERE status = 'ONGOING';

-- W05's delete predicate and the expensive payments_trip_id_fkey checks.
-- Keep the LIKE predicate text aligned with W05 so PostgreSQL can prove that
-- the DELETE's WHERE clause implies this partial-index predicate.
CREATE INDEX trips_cancelled_requested_at_idx
    ON trips (requested_at)
    WHERE status LIKE 'CANCELLED%';

CREATE INDEX payments_trip_id_idx
    ON payments (trip_id);

-- R03 uses LOWER(email); the existing unique(email) index cannot serve it.
CREATE INDEX riders_lower_email_idx
    ON riders (lower(email));

-- R08 and R22 filter payments by status and paid_at window.
CREATE INDEX payments_status_paid_at_idx
    ON payments (payment_status, paid_at);
