create database ola;
use ola;
CREATE TABLE bookings (
    booking_ID VARCHAR(50),
    booking_Status VARCHAR(50),
    customer_ID VARCHAR(50),
    vehicle_Type VARCHAR(50),
    pickup_Location VARCHAR(100),
    drop_Location VARCHAR(100),
    incomplete_Rides VARCHAR(50),
    booking_Value VARCHAR(50),     -- changed to VARCHAR ✅
    payment_Method VARCHAR(50),
    ride_Distance VARCHAR(50),     -- safe
    driver_Ratings VARCHAR(50),    -- safe
    customer_Rating VARCHAR(50)    -- safe
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Bookings-20000-Rows.csv'
INTO TABLE bookings
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM bookings;
SELECT * FROM bookings LIMIT 5;
SELECT booking_Status, COUNT(*) 
FROM bookings
GROUP BY booking_Status;

SELECT * FROM bookings;

SELECT 
  booking_Value,
  CAST(booking_Value AS DECIMAL(10,2)) AS booking_value_clean
FROM bookings;

SELECT DISTINCT booking_Value
FROM bookings
LIMIT 10;

ALTER TABLE bookings
ADD booking_value_clean DECIMAL(10,2);

SET SQL_SAFE_UPDATES = 0;

UPDATE bookings
SET booking_value_clean =
CASE
    WHEN booking_Value IS NULL 
         OR booking_Value = 'null' 
         OR booking_Value = ''
    THEN NULL

    WHEN booking_Value REGEXP '^[0-9.,]+$'
    THEN CAST(REPLACE(booking_Value, ',', '') AS DECIMAL(10,2))

    ELSE NULL
END;
SELECT booking_Value, booking_value_clean
FROM bookings
LIMIT 15;

ALTER TABLE bookings
ADD ride_distance_clean DECIMAL(10,2);

SET SQL_SAFE_UPDATES = 0;

UPDATE bookings
SET ride_distance_clean =
CASE
    WHEN ride_Distance IS NULL 
         OR ride_Distance = 'null' 
         OR ride_Distance = ''
    THEN NULL

    WHEN ride_Distance REGEXP '^[0-9.,]+$'
    THEN CAST(REPLACE(ride_Distance, ',', '') AS DECIMAL(10,2))

    ELSE NULL
END;

SELECT ride_distance, ride_distance_clean
FROM bookings
LIMIT 15;

ALTER TABLE bookings
MODIFY driver_rating_clean DECIMAL(4,2),
MODIFY customer_rating_clean DECIMAL(4,2);

SET SQL_SAFE_UPDATES = 0;

UPDATE bookings
SET
driver_rating_clean =
CASE
    WHEN driver_Ratings IS NULL 
         OR driver_Ratings = 'null' 
         OR driver_Ratings = ''
    THEN NULL

    WHEN driver_Ratings REGEXP '^[0-9.]+$'
         AND CAST(driver_Ratings AS DECIMAL(4,2)) BETWEEN 0 AND 10
    THEN CAST(driver_Ratings AS DECIMAL(4,2))

    ELSE NULL
END,

customer_rating_clean =
CASE
    WHEN customer_Rating IS NULL 
         OR customer_Rating = 'null' 
         OR customer_Rating = ''
    THEN NULL

    WHEN customer_Rating REGEXP '^[0-9.]+$'
         AND CAST(customer_Rating AS DECIMAL(4,2)) BETWEEN 0 AND 10
    THEN CAST(customer_Rating AS DECIMAL(4,2))

    ELSE NULL
END;
SELECT 
driver_Ratings, driver_rating_clean,
customer_Rating, customer_rating_clean
FROM bookings
LIMIT 15;
#How many rides were completed/cancelled
#How much revenue each status generated
SELECT 
    booking_Status,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS total_revenue
FROM bookings
GROUP BY booking_Status
ORDER BY total_rides DESC;

#Which vehicle type earns the most?
#Which vehicle type to promote
#Which gives higher value per ride
SELECT 
    vehicle_Type,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS total_revenue,
    ROUND(AVG(booking_value_clean), 2) AS avg_booking_value
FROM bookings
GROUP BY vehicle_Type
ORDER BY total_revenue DESC;

#Do higher ratings relate to better rides
#Are cancelled rides rated lower?
#Do completed rides have better ratings?
SELECT 
    booking_Status,
    ROUND(AVG(driver_rating_clean), 2) AS avg_driver_rating,
    ROUND(AVG(customer_rating_clean), 2) AS avg_customer_rating
FROM bookings
GROUP BY booking_Status;

#How many rides are incomplete and how much revenue is lost
#Helps identify loss areas
#Used by operations team to reduce failures
SELECT 
    incomplete_Rides,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS revenue
FROM bookings
GROUP BY incomplete_Rides;

#While analyzing incomplete rides, I identified data quality issues such as NULLs, blank values, and header leakage.
# I created a cleaned categorical column to standardize values before performing operational analysis.

ALTER TABLE bookings
ADD incomplete_rides_clean VARCHAR(30);

UPDATE bookings
SET incomplete_rides_clean =
CASE
    WHEN incomplete_Rides IN ('Yes', 'No')
    THEN incomplete_Rides
    ELSE 'Unknown'
END;

SELECT
    incomplete_rides_clean,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS revenue
FROM bookings
GROUP BY incomplete_rides_clean;

#Which payment methods are customers using, and which ones generate the most revenue?”
#Why this matters:
#Finance team → prefers reliable methods
#Product team → promotes popular methods
#Ops team → checks failures in cash vs online

SELECT
    payment_Method,
    COUNT(*) AS total_rides
FROM bookings
GROUP BY payment_Method
ORDER BY total_rides DESC;

SELECT
    payment_Method,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS total_revenue,
    ROUND(AVG(booking_value_clean), 2) AS avg_revenue_per_ride
FROM bookings
GROUP BY payment_Method
ORDER BY total_revenue DESC;

#only susscesfull rides
SELECT
    payment_Method,
    COUNT(*) AS successful_rides,
    ROUND(SUM(booking_value_clean), 2) AS revenue
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY payment_Method
ORDER BY revenue DESC;

#average revenue per ride
SELECT
    payment_Method,
    COUNT(*) AS rides,
    ROUND(AVG(booking_value_clean), 2) AS avg_revenue
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY payment_Method
ORDER BY avg_revenue DESC;

#cancelation rate by payment method
SELECT
    payment_Method,
    SUM(CASE WHEN booking_Status != 'Success' THEN 1 ELSE 0 END) AS failed_rides,
    COUNT(*) AS total_rides
FROM bookings
GROUP BY payment_Method;

#Among completed rides, which payment method dominates
SELECT
    payment_Method,
    COUNT(*) AS successful_rides
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY payment_Method
ORDER BY successful_rides DESC;

#Which pickup locations have the highest demand
SELECT 
    pickup_Location, COUNT(*) AS total_rides
FROM
    bookings
WHERE
    booking_Status = 'Success'
GROUP BY pickup_Location
ORDER BY total_rides DESC
LIMIT 10;

#which drop location are most comman
SELECT
    drop_Location,
    COUNT(*) AS total_rides
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY drop_Location
ORDER BY total_rides DESC
LIMIT 10;

#Which routes are most frequently traveled
SELECT
    pickup_Location,
    drop_Location,
    COUNT(*) AS total_rides
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY pickup_Location, drop_Location
ORDER BY total_rides DESC
LIMIT 10;

#Which pickup locations generate the most revenue
SELECT
    pickup_Location,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS total_revenue
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY pickup_Location
ORDER BY total_revenue DESC
LIMIT 10;

SELECT
    pickup_Location,
    COUNT(*) AS total_rides,
    ROUND(SUM(booking_value_clean), 2) AS total_revenue,
    ROUND(AVG(booking_value_clean), 2) AS avg_revenue_per_ride
FROM bookings
WHERE booking_Status = 'Success'
GROUP BY pickup_Location
ORDER BY total_rides DESC
limit 10;
















































