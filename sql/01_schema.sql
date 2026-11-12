-- Uber Ride-Hailing database schema
-- Constraints only: no performance indexes are created in this phase.

CREATE SCHEMA IF NOT EXISTS uber;
SET search_path TO uber;

CREATE TABLE cities (
    city_id       integer        NOT NULL,
    city_name     text           NOT NULL,
    state         text           NOT NULL,
    base_fare     numeric(8, 2)  NOT NULL,
    per_km_rate   numeric(8, 2)  NOT NULL,
    per_min_rate  numeric(8, 2)  NOT NULL,
    launched_on   date           NOT NULL,

    CONSTRAINT cities_pkey PRIMARY KEY (city_id),
    CONSTRAINT cities_city_name_key UNIQUE (city_name),
    CONSTRAINT cities_base_fare_check CHECK (base_fare > 0),
    CONSTRAINT cities_per_km_rate_check CHECK (per_km_rate > 0),
    CONSTRAINT cities_per_min_rate_check CHECK (per_min_rate > 0)
);

CREATE TABLE riders (
    rider_id       integer       NOT NULL,
    full_name      text          NOT NULL,
    email          text          NOT NULL,
    phone          text          NOT NULL,
    home_city_id   integer       NOT NULL,
    signup_date    date          NOT NULL,
    rider_rating   numeric(2, 1),
    is_active      boolean       NOT NULL,

    CONSTRAINT riders_pkey PRIMARY KEY (rider_id),
    CONSTRAINT riders_email_key UNIQUE (email),
    CONSTRAINT riders_phone_key UNIQUE (phone),
    CONSTRAINT riders_home_city_id_fkey
        FOREIGN KEY (home_city_id)
        REFERENCES cities (city_id)
        ON DELETE RESTRICT,
    CONSTRAINT riders_rating_check
        CHECK (rider_rating IS NULL OR rider_rating BETWEEN 1.0 AND 5.0)
);

CREATE TABLE drivers (
    driver_id      integer       NOT NULL,
    full_name      text          NOT NULL,
    phone          text          NOT NULL,
    license_no     text          NOT NULL,
    city_id        integer       NOT NULL,
    joined_on      date          NOT NULL,
    driver_rating  numeric(2, 1) NOT NULL,
    status         text          NOT NULL,

    CONSTRAINT drivers_pkey PRIMARY KEY (driver_id),
    CONSTRAINT drivers_phone_key UNIQUE (phone),
    CONSTRAINT drivers_license_no_key UNIQUE (license_no),
    CONSTRAINT drivers_city_id_fkey
        FOREIGN KEY (city_id)
        REFERENCES cities (city_id)
        ON DELETE RESTRICT,
    CONSTRAINT drivers_rating_check CHECK (driver_rating BETWEEN 1.0 AND 5.0),
    CONSTRAINT drivers_status_check
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
);

CREATE TABLE vehicles (
    vehicle_id       integer   NOT NULL,
    driver_id        integer   NOT NULL,
    registration_no  text      NOT NULL,
    make             text      NOT NULL,
    model            text      NOT NULL,
    manufacture_year smallint  NOT NULL,
    vehicle_type     text      NOT NULL,
    seat_capacity    smallint  NOT NULL,

    CONSTRAINT vehicles_pkey PRIMARY KEY (vehicle_id),
    CONSTRAINT vehicles_registration_no_key UNIQUE (registration_no),
    CONSTRAINT vehicles_driver_id_fkey
        FOREIGN KEY (driver_id)
        REFERENCES drivers (driver_id)
        ON DELETE RESTRICT,
    CONSTRAINT vehicles_type_check
        CHECK (vehicle_type IN ('AUTO', 'BIKE', 'MINI', 'SEDAN', 'SUV')),
    CONSTRAINT vehicles_seat_capacity_check CHECK (seat_capacity > 0)
);

CREATE TABLE promo_codes (
    promo_code    text          NOT NULL,
    discount_pct  numeric(5, 2) NOT NULL,
    max_discount  numeric(8, 2) NOT NULL,
    valid_from    date          NOT NULL,
    valid_to      date          NOT NULL,
    is_active     boolean       NOT NULL,

    CONSTRAINT promo_codes_pkey PRIMARY KEY (promo_code),
    CONSTRAINT promo_codes_discount_pct_check
        CHECK (discount_pct > 0 AND discount_pct <= 100),
    CONSTRAINT promo_codes_max_discount_check CHECK (max_discount >= 0),
    CONSTRAINT promo_codes_valid_dates_check CHECK (valid_to >= valid_from)
);

CREATE TABLE trips (
    trip_id          integer         NOT NULL,
    rider_id         integer         NOT NULL,
    driver_id        integer,
    vehicle_id       integer,
    city_id          integer         NOT NULL,
    promo_code       text,
    requested_at     timestamptz     NOT NULL,
    pickup_at        timestamptz,
    dropoff_at       timestamptz,
    pickup_lat       numeric(9, 6)   NOT NULL,
    pickup_lng       numeric(9, 6)   NOT NULL,
    drop_lat         numeric(9, 6)   NOT NULL,
    drop_lng         numeric(9, 6)   NOT NULL,
    distance_km      numeric(8, 2),
    duration_min     smallint,
    surge_multiplier numeric(4, 2)   NOT NULL,
    fare_amount      numeric(10, 2),
    status           text            NOT NULL,

    CONSTRAINT trips_pkey PRIMARY KEY (trip_id),
    CONSTRAINT trips_rider_id_fkey
        FOREIGN KEY (rider_id)
        REFERENCES riders (rider_id)
        ON DELETE RESTRICT,
    CONSTRAINT trips_driver_id_fkey
        FOREIGN KEY (driver_id)
        REFERENCES drivers (driver_id)
        ON DELETE RESTRICT,
    CONSTRAINT trips_vehicle_id_fkey
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicles (vehicle_id)
        ON DELETE RESTRICT,
    CONSTRAINT trips_city_id_fkey
        FOREIGN KEY (city_id)
        REFERENCES cities (city_id)
        ON DELETE RESTRICT,
    CONSTRAINT trips_promo_code_fkey
        FOREIGN KEY (promo_code)
        REFERENCES promo_codes (promo_code)
        ON DELETE RESTRICT,
    CONSTRAINT trips_status_check
        CHECK (status IN (
            'REQUESTED', 'ACCEPTED', 'ONGOING', 'COMPLETED',
            'CANCELLED_BY_RIDER', 'CANCELLED_BY_DRIVER'
        )),
    CONSTRAINT trips_pickup_lat_check CHECK (pickup_lat BETWEEN -90 AND 90),
    CONSTRAINT trips_pickup_lng_check CHECK (pickup_lng BETWEEN -180 AND 180),
    CONSTRAINT trips_drop_lat_check CHECK (drop_lat BETWEEN -90 AND 90),
    CONSTRAINT trips_drop_lng_check CHECK (drop_lng BETWEEN -180 AND 180),
    CONSTRAINT trips_surge_multiplier_check CHECK (surge_multiplier >= 1.00),
    CONSTRAINT trips_distance_km_check
        CHECK (distance_km IS NULL OR distance_km > 0),
    CONSTRAINT trips_duration_min_check
        CHECK (duration_min IS NULL OR duration_min > 0),
    CONSTRAINT trips_fare_amount_check
        CHECK (fare_amount IS NULL OR fare_amount >= 0),
    CONSTRAINT trips_dropoff_after_pickup_check
        CHECK (pickup_at IS NULL OR dropoff_at IS NULL OR dropoff_at > pickup_at),
    CONSTRAINT trips_completed_fields_check
        CHECK (
            status <> 'COMPLETED'
            OR (
                driver_id IS NOT NULL
                AND vehicle_id IS NOT NULL
                AND pickup_at IS NOT NULL
                AND dropoff_at IS NOT NULL
                AND distance_km IS NOT NULL
                AND duration_min IS NOT NULL
                AND fare_amount IS NOT NULL
            )
        )
);

CREATE TABLE payments (
    payment_id     integer         NOT NULL,
    trip_id        integer         NOT NULL,
    amount         numeric(10, 2)  NOT NULL,
    method         text            NOT NULL,
    payment_status text            NOT NULL,
    paid_at        timestamptz     NOT NULL,

    CONSTRAINT payments_pkey PRIMARY KEY (payment_id),
    CONSTRAINT payments_trip_id_fkey
        FOREIGN KEY (trip_id)
        REFERENCES trips (trip_id)
        ON DELETE RESTRICT,
    CONSTRAINT payments_amount_check CHECK (amount >= 0),
    CONSTRAINT payments_method_check
        CHECK (method IN ('CARD', 'CASH', 'UPI', 'WALLET')),
    CONSTRAINT payments_status_check
        CHECK (payment_status IN ('SUCCESS', 'FAILED', 'REFUNDED'))
);

CREATE TABLE ratings (
    trip_id    integer      NOT NULL,
    rated_by   text         NOT NULL,
    stars      smallint     NOT NULL,
    comment    text,
    created_at timestamptz  NOT NULL,

    CONSTRAINT ratings_pkey PRIMARY KEY (trip_id, rated_by),
    CONSTRAINT ratings_trip_id_fkey
        FOREIGN KEY (trip_id)
        REFERENCES trips (trip_id)
        ON DELETE RESTRICT,
    CONSTRAINT ratings_rated_by_check CHECK (rated_by IN ('RIDER', 'DRIVER')),
    CONSTRAINT ratings_stars_check CHECK (stars BETWEEN 1 AND 5)
);
