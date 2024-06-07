-- checking for issues in data, looking for duplicates 

SELECT distinct date, pollutant, count(*) FROM pollution.grazp
group by date, pollutant;

-- O3 has less records than the other pollutants and after checking the dates, it has data only after 2021

SELECT pollutant, count(pollutant) from grazp
GROUP BY pollutant;

SELECT date FROM grazp
WHERE pollutant = "O3";

-- based on WHO guidelines, I wanted to asses if the concentration is unhealthy or not. For easier analysis, I created a view that assess the quality of the air by checking if the concentration was above or below the suggested values. 

CREATE VIEW pollution.grazq
AS
Select Date, Pollutant, AvgConc, Unit,
	CASE 
		WHEN Pollutant = "PM2.5" and AvgConc > 15 THEN "Unhealthy"
        WHEN Pollutant = "PM10" and AvgConc > 45 THEN "Unhealthy"
        WHEN Pollutant = "NO2" and AvgConc > 25 THEN "Unhealthy"
        WHEN Pollutant = "CO" and AvgConc > 4 THEN "Unhealthy"
		WHEN Pollutant = "SO2" and AvgConc > 40 THEN "Unhealthy"
        WHEN Pollutant = "O3" and AvgConc > 100 THEN "Unhealthy"
        ELSE "OK"
	END as quality
FROM grazp;

-- Checking the days when there was an unhealthy cocnentration of pollutant
-- Checking the number of days where each pollutant was above healthy level

Select date, Pollutant FROM grazq
WHERE quality = "Unhealthy";

SELECT pollutant, count(*) as unhealthy_days from grazq
WHERE quality = "Unhealthy"
GROUP BY pollutant
ORDER BY unhealthy_days DESC;

-- Expressing the total number of unhealthy days in percentage per pollutant

WITH pctg AS (
SELECT pollutant, count(*) as unhealthy_days from grazq
WHERE quality = "Unhealthy"
GROUP BY pollutant)
SELECT grazq.pollutant, count(grazq.pollutant) as total_days, pctg.unhealthy_days, round((pctg.unhealthy_days / count(grazq.pollutant))*100,1) as percentage
FROM grazq
JOIN pctg ON grazq.pollutant = pctg.pollutant
GROUP BY grazq.pollutant, pctg.unhealthy_days
ORDER BY percentage DESC
;

-- check if there's a seasonality in increased pollution on a monthly basis based on pollutants - December and January are the most polluted months 

SELECT YEAR(date) as year, MONTH(date) as month, pollutant, count(*) as days, round(avg(AvgConc),1) from grazq
WHERE quality = "Unhealthy" 
GROUP BY YEAR(date), MONTH(date), pollutant
ORDER BY days DESC;

-- When selecting only the months, it can be seen clearly that the summer months are lower in pollution

SELECT MONTH(date) as month, count(*) as days, round(avg(AvgConc),1) from grazq
WHERE quality = "Unhealthy" 
GROUP BY  MONTH(date)
ORDER BY days DESC;

-- some interesting facts/aggregations
SELECT pollutant, MIN(AvgConc) as min, MAX(AvgConc) as max, AVG(AvgConc) as avg
FROM grazq
GROUP BY pollutant;

SELECT date, pollutant FROM grazq
WHERE AvgConc < 0