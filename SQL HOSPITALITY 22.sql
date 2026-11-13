
use Hotel_booking;
select count(*) from dim_date;
select count(*) from dim_hotels;
select count(*) from dim_rooms;
select count(*) from fact_aggregated_bookings;
select count(*) from fact_bookings;

SELECT 'dim_date' AS table_name, COUNT(*) AS row_count
FROM dim_date
UNION ALL
SELECT 'dim_hotels', COUNT(*) FROM dim_hotels
UNION ALL
SELECT 'dim_rooms', COUNT(*) FROM dim_rooms
UNION ALL
SELECT 'fact_aggregated_bookings', COUNT(*)
FROM fact_aggregated_bookings
UNION ALL
SELECT 'fact_bookings', COUNT(*)
FROM fact_bookings;

use Hotel_booking ; 

select count(*) from fact_bookings;
select count(*)  from dim_date;
select count(*) from dim_hotels;
select count(*) from dim_rooms;
select count(*) from fact_aggregated_bookings;
select count(*) from fact_bookings;

SELECT booking_status, COUNT(*) AS bookings
FROM fact_bookings
GROUP BY booking_status;

#REMOVE DUPLICATE BOOKING IDS 
SELECT booking_id, COUNT(*) AS occurrences
FROM fact_bookings
GROUP BY booking_id
HAVING COUNT(*) > 1;

#PROPERTY IDS AND DIMENSIONS
SELECT DISTINCT f.property_id
FROM fact_bookings f
LEFT JOIN dim_hotels h
    ON f.property_id = h.property_id
WHERE h.property_id IS NULL;

DESCRIBE fact_bookings;
DESCRIBE fact_aggregated_bookings;
DESCRIBE dim_date;
describe dim_hotels ;
describe dim_rooms ;

SELECT
    f.booking_id,
    f.property_id,
    h.property_name,
    h.city,
    h.category AS hotel_category,
    f.booking_date,
    f.check_in_date,
    f.checkout_date,
    d.day_type,
    f.no_guests,
    f.room_category,
    r.room_class,
    f.booking_platform,
    f.ratings_given,
    f.booking_status,
    f.revenue_generated,
    f.revenue_realized
FROM fact_bookings AS f
left JOIN dim_hotels AS h
    ON f.property_id = h.property_id
left JOIN dim_rooms AS r
    ON f.room_category = r.room_id
left JOIN dim_date AS d
    ON f.check_in_date = d.date;
    
    SELECT
    a.property_id,
    h.property_name,
    h.city,
    a.check_in_date,
    d.day_type,
    a.room_category,
    r.room_class,
    a.successful_bookings,
    a.capacity
FROM fact_aggregated_bookings AS a
left JOIN dim_hotels AS h
    ON a.property_id = h.property_id
left JOIN dim_rooms AS r
    ON a.room_category = r.room_id
left JOIN dim_date AS d
    ON a.check_in_date = d.date;



CREATE OR REPLACE VIEW view_bookings AS
SELECT
    booking_id,
    property_id,
    CASE
        WHEN booking_date IS NULL OR booking_date = ''
        THEN NULL
        ELSE STR_TO_DATE(booking_date, '%d-%m-%Y')
    END AS booking_date,
    CASE
        WHEN check_in_date IS NULL OR check_in_date = ''
        THEN NULL
        ELSE STR_TO_DATE(check_in_date, '%d-%m-%Y')
    END AS check_in_date,
    CASE
        WHEN checkout_date IS NULL OR checkout_date = ''
        THEN NULL
        ELSE STR_TO_DATE(checkout_date, '%d-%m-%Y')
    END AS checkout_date,
    no_guests,
    room_category,
    booking_platform,
    ratings_given,
    booking_status,
    revenue_generated,
    revenue_realized
FROM fact_bookings;

#KPI'S
SELECT
    COUNT(booking_id) AS total_bookings,
    SUM(revenue_generated) AS revenue_generated,
    SUM(revenue_realized) AS revenue,
    SUM(CASE
        WHEN booking_status = 'Checked Out'
        THEN 1 ELSE 0
    END) AS checked_out_bookings,
    SUM(CASE
        WHEN booking_status = 'Cancelled'
        THEN 1 ELSE 0
    END) AS cancelled_bookings,
    SUM(CASE
        WHEN booking_status = 'No Show'
        THEN 1 ELSE 0
    END) AS no_show_bookings,
    ROUND(
        100.0 * SUM(
            CASE WHEN booking_status = 'Checked Out'
            THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(booking_id), 0),
        2
    ) AS realisation_pct,
    ROUND(
        100.0 * SUM(
            CASE WHEN booking_status = 'Cancelled'
            THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(booking_id), 0),
        2
    ) AS cancellation_pct,
    SUM(revenue_generated) - SUM(revenue_realized)
        AS revenue_leakage,
    ROUND(
        SUM(revenue_realized) /
        NULLIF(SUM(
            CASE WHEN booking_status = 'Checked Out'
            THEN 1 ELSE 0 END
        ), 0),
        2
    ) AS adr_checked_out,
    ROUND(AVG(ratings_given), 2) AS average_rating
FROM view_bookings;

#TOTAL BOOKINGS & REVENUE BY CITY
SELECT
    h.city,
    COUNT(b.booking_id) AS total_bookings,
    SUM(b.revenue_realized) AS revenue,
    SUM(b.revenue_generated) AS revenue_generated
FROM view_bookings b
JOIN dim_hotels h
    ON b.property_id = h.property_id
GROUP BY h.city
ORDER BY revenue DESC;


#RevPAR BY CITY
WITH city_revenue AS (
    SELECT
        h.city,
        SUM(b.revenue_realized) AS revenue
    FROM view_bookings b
    JOIN dim_hotels h
        ON b.property_id = h.property_id
    GROUP BY h.city
),
city_capacity AS (
    SELECT
        h.city,
        SUM(a.capacity) AS available_room_nights
    FROM fact_aggregated_bookings a
    JOIN dim_hotels h
        ON a.property_id = h.property_id
    GROUP BY h.city
)
SELECT
    r.city,
    r.revenue,
    c.available_room_nights,
    ROUND(
        r.revenue /
        NULLIF(c.available_room_nights, 0),
        2
    ) AS revenue_per_available_room_night
FROM city_revenue r
JOIN city_capacity c
    ON r.city = c.city
ORDER BY revenue_per_available_room_night DESC;

#AVAILABLE ROOM NIGHTS BY CITY
SELECT
    h.city,
    SUM(a.capacity) AS available_room_nights,
    SUM(a.successful_bookings) AS successful_room_bookings,
    ROUND(
        100.0 * SUM(a.successful_bookings) /
        NULLIF(SUM(a.capacity), 0),
        2
    ) AS booked_occupancy_pct
FROM fact_aggregated_bookings a
JOIN dim_hotels h
    ON a.property_id = h.property_id
GROUP BY h.city
ORDER BY available_room_nights DESC;



SELECT
    booking_status,
    COUNT(booking_id) AS total_bookings,
    ROUND(
        100.0 * COUNT(booking_id) /
        (SELECT COUNT(*) FROM view_bookings),
        2
    ) AS booking_share_pct
FROM view_bookings
GROUP BY booking_status
ORDER BY total_bookings DESC;


#BOOKING SHARE BY PLATFORM
SELECT
    booking_platform,
    COUNT(booking_id) AS total_bookings,
    ROUND(
        100.0 * COUNT(booking_id) /
        (SELECT COUNT(*) FROM view_bookings),
        2
    ) AS booking_share_pct,
    SUM(revenue_realized) AS revenue
FROM view_bookings
GROUP BY booking_platform
ORDER BY total_bookings DESC;


#CANCELLATION % BY CITY
SELECT
    h.city,
    COUNT(b.booking_id) AS total_bookings,
    SUM(CASE
        WHEN b.booking_status = 'Cancelled'
        THEN 1 ELSE 0
    END) AS cancelled_bookings,
    ROUND(
        100.0 * SUM(
            CASE WHEN b.booking_status = 'Cancelled'
            THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(b.booking_id), 0),
        2
    ) AS cancellation_pct
FROM view_bookings b
JOIN dim_hotels h
    ON b.property_id = h.property_id
GROUP BY h.city
ORDER BY cancellation_pct DESC;


#RATINGS
SELECT
    ratings_given AS rating_star,
    COUNT(*) AS rated_bookings
FROM view_bookings
WHERE ratings_given BETWEEN 1 AND 5
GROUP BY ratings_given
ORDER BY rating_star;


#TOP 5 PROPERTIES BY REVENUE LEKAGE
SELECT
    h.property_id,
    h.property_name,
    h.city,
    SUM(b.revenue_generated) AS revenue_generated,
    SUM(b.revenue_realized) AS revenue_realized,
    SUM(b.revenue_generated) -
    SUM(b.revenue_realized) AS revenue_leakage
FROM view_bookings b
JOIN dim_hotels h
    ON b.property_id = h.property_id
GROUP BY
    h.property_id,
    h.property_name,
    h.city
ORDER BY revenue_leakage DESC
LIMIT 5;


#DAILY OCCUPANCY
WITH daily_capacity AS (
    SELECT
        check_in_date AS stay_date,
        SUM(successful_bookings) AS booked_room_nights,
        SUM(capacity) AS available_room_nights
    FROM fact_aggregated_bookings
    GROUP BY check_in_date
)
SELECT
    stay_date,
    booked_room_nights,
    available_room_nights,
    ROUND(
        100.0 * booked_room_nights /
        NULLIF(available_room_nights, 0),
        2
    ) AS booked_occupancy_pct
FROM daily_capacity
ORDER BY stay_date;


#DBRN,DSRN,DURN
WITH daily_bookings AS (
    SELECT
        check_in_date AS stay_date,
        COUNT(booking_id) AS booking_records,
        SUM(CASE
            WHEN booking_status = 'Checked Out'
            THEN 1 ELSE 0
        END) AS checked_out_bookings
    FROM view_bookings
    GROUP BY check_in_date
),
daily_rooms AS (
    SELECT
        check_in_date AS stay_date,
        SUM(successful_bookings) AS successful_room_bookings,
        SUM(capacity) AS available_room_nights
    FROM fact_aggregated_bookings
    GROUP BY check_in_date
),
summary AS (
    SELECT
        (SELECT COUNT(*) FROM dim_date) AS total_days,
        (SELECT SUM(successful_room_bookings)
         FROM daily_rooms) AS total_successful_room_bookings,
        (SELECT SUM(available_room_nights)
         FROM daily_rooms) AS total_capacity,
        (SELECT SUM(checked_out_bookings)
         FROM daily_bookings) AS total_checked_out
)
SELECT
    total_days,
    ROUND(
        total_successful_room_bookings /
        NULLIF(total_days, 0), 2
    ) AS DBRN,
    ROUND(
        total_capacity /
        NULLIF(total_days, 0), 2
    ) AS DSRN,
    ROUND(
        total_checked_out /
        NULLIF(total_days, 0), 2
    ) AS DURN
FROM summary;



#WEEKDAY vs WEEKEND OCCUPANCY
SELECT
    d.day_type,
    SUM(a.successful_bookings) AS booked_room_nights,
    SUM(a.capacity) AS available_room_nights,
    ROUND(
        100.0 * SUM(a.successful_bookings) /
        NULLIF(SUM(a.capacity), 0),
        2
    ) AS booked_occupancy_pct
FROM fact_aggregated_bookings a
JOIN dim_date d
    ON DATE_FORMAT(a.check_in_date, '%Y-%m-%d') =
       DATE_FORMAT(
           STR_TO_DATE(d.date, '%d-%b-%y'),
           '%Y-%m-%d'
       )
GROUP BY d.day_type
ORDER BY booked_occupancy_pct DESC;


#WEEKLY REVENUE & BOOKED OCCUPANCY
WITH booking_week AS (
    SELECT
        YEARWEEK(check_in_date, 0) AS week_key,
        SUM(revenue_realized) AS revenue,
        COUNT(booking_id) AS total_bookings
    FROM view_bookings
    GROUP BY YEARWEEK(check_in_date, 0)
),
room_week AS (
    SELECT
        YEARWEEK(check_in_date, 0) AS week_key,
        SUM(successful_bookings) AS booked_room_nights,
        SUM(capacity) AS available_room_nights
    FROM fact_aggregated_bookings
    GROUP BY YEARWEEK(check_in_date, 0)
)
SELECT
    r.week_key,
    r.revenue,
    r.total_bookings,
    a.booked_room_nights,
    a.available_room_nights,
    ROUND(
        100.0 * a.booked_room_nights /
        NULLIF(a.available_room_nights, 0),
        2
    ) AS booked_occupancy_pct
FROM booking_week r
JOIN room_week a
    ON r.week_key = a.week_key
ORDER BY r.week_key;


#WEEKLY REVENUE & OCCUPANCY CHANGE
WITH weekly AS (
    SELECT
        YEARWEEK(check_in_date, 0) AS week_key,
        SUM(revenue_realized) AS revenue
    FROM view_bookings
    GROUP BY YEARWEEK(check_in_date, 0)
),
comparison AS (
    SELECT
        week_key,
        revenue,
        LAG(revenue) OVER (
            ORDER BY week_key
        ) AS previous_week_revenue
    FROM weekly
)
SELECT
    week_key,
    revenue,
    previous_week_revenue,
    ROUND(
        100.0 * (revenue - previous_week_revenue) /
        NULLIF(previous_week_revenue, 0),
        2
    ) AS revenue_wow_pct
FROM comparison
ORDER BY week_key;


SELECT
    d.date,
    STR_TO_DATE(d.date, '%d-%b-%y') AS converted_date,
    a.check_in_date
FROM dim_date AS d
LEFT JOIN fact_aggregated_bookings AS a
    ON STR_TO_DATE(d.date, '%d-%b-%y') = a.check_in_date
LIMIT 10;

DESCRIBE fact_aggregated_bookings;

SELECT
    check_in_date,
    LENGTH(check_in_date) AS value_length
FROM fact_aggregated_bookings
LIMIT 10;

SELECT
    check_in_date,
    STR_TO_DATE(check_in_date, '%d-%b-%y') AS converted_date
FROM fact_aggregated_bookings
LIMIT 10;

SELECT
    d.date,
    a.check_in_date,
    STR_TO_DATE(d.date, '%d-%b-%y') AS dim_date_converted,
    STR_TO_DATE(a.check_in_date, '%d-%b-%y') AS booking_date_converted
FROM dim_date AS d
LEFT JOIN fact_aggregated_bookings AS a
    ON STR_TO_DATE(d.date, '%d-%b-%y')
     = STR_TO_DATE(a.check_in_date, '%d-%b-%y')
LIMIT 10;

SELECT
    d.day_type,

    SUM(a.successful_bookings) AS booked_room_nights,

    SUM(a.capacity) AS available_room_nights,

    ROUND(
        100.0 * SUM(a.successful_bookings)
        / NULLIF(SUM(a.capacity), 0),
        2
    ) AS booked_occupancy_pct

FROM fact_aggregated_bookings AS a

INNER JOIN dim_date AS d
    ON STR_TO_DATE(a.check_in_date, '%d-%b-%y')
     = STR_TO_DATE(d.date, '%d-%b-%y')

GROUP BY d.day_type;


SELECT
    FLOOR(
        DATEDIFF(
            STR_TO_DATE(d.date, '%d-%b-%y'),
            '2022-05-01'
        ) / 7
    ) + 1 AS week_no,

    DAYNAME(
        STR_TO_DATE(d.date, '%d-%b-%y')
    ) AS weekday_name,

    SUM(a.successful_bookings) AS booked_room_nights,

    SUM(a.capacity) AS available_room_nights,

    ROUND(
        100.0 * SUM(a.successful_bookings)
        / NULLIF(SUM(a.capacity), 0),
        2
    ) AS occupancy_pct

FROM fact_aggregated_bookings AS a

INNER JOIN dim_date AS d
    ON STR_TO_DATE(a.check_in_date, '%d-%b-%y')
     = STR_TO_DATE(d.date, '%d-%b-%y')

GROUP BY
    week_no,
    weekday_name

ORDER BY
    week_no,
    MIN(STR_TO_DATE(d.date, '%d-%b-%y'));
    
    
    #OCCUPANCY HEATMAP: WEEKDAY & WEEK
    SELECT
    FLOOR(
        DATEDIFF(
            STR_TO_DATE(d.date, '%d-%b-%y'),
            '2022-05-01'
        ) / 7
    ) + 1 AS week_no,
    DAYNAME(
        STR_TO_DATE(d.date, '%d-%b-%y')
    ) AS weekday_name,
    ROUND(
        100.0 * SUM(a.successful_bookings)
        / NULLIF(SUM(a.capacity), 0),
        2
    ) AS occupancy_pct
FROM fact_aggregated_bookings AS a
INNER JOIN dim_date AS d
    ON STR_TO_DATE(a.check_in_date, '%d-%b-%y')
     = STR_TO_DATE(d.date, '%d-%b-%y')
GROUP BY
    week_no,
    weekday_name
ORDER BY
    week_no,
    MIN(STR_TO_DATE(d.date, '%d-%b-%y'));
