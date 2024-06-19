-- Cleaning and transforming table data "fuel_consumption"

SELECT * from fuel_consumption
LIMIT 20;

-- I don't need many of these columns, so I will delete them from this database
ALTER TABLE fuel_consumption 
DROP COLUMN STRUCTURE,
DROP COLUMN STRUCTURE_ID,
DROP COLUMN STRUCTURE_NAME,
DROP COLUMN Energy_balance,
DROP COLUMN freq,
DROP COLUMN nrg_bal,
DROP COLUMN siec,
DROP COLUMN OBS_FLAG,
DROP COLUMN Observation_status_Flag,
DROP COLUMN Observation_value;

ALTER TABLE fuel_consumption
DROP COLUMN Unit_of_measure,
DROP COLUMN geo;

-- Renaming the columns for easier usage
ALTER TABLE fuel_consumption 
RENAME COLUMN Standard_international_energy_product_classification_SIEC TO fuel_type,
RENAME COLUMN Geopolitical_entity_reporting TO country,
RENAME COLUMN TIME_PERIOD TO year,
RENAME COLUMN OBS_VALUE TO value;

-- Cleaning and transforming table data "consumption_quantity"

SELECT * from consumption_quantity
LIMIT 10;

ALTER TABLE consumption_quantity
DROP COLUMN nrg_bal,
DROP COLUMN siec,
DROP COLUMN OBS_FLAG;

UPDATE consumption_quantity
SET unit = 'GWH';

-- selecting all geo-countries so I can see if I can delete the first 3 characters from all rows
SELECT geo from consumption_quantity
GROUP BY geo;

UPDATE consumption_quantity
SET geo = substring(geo,4);
UPDATE consumption_quantity
SET freq = substring(freq,3);

ALTER TABLE consumption_quantity 
RENAME COLUMN geo TO country,
RENAME COLUMN TIME_PERIOD TO year,
RENAME COLUMN OBS_VALUE TO value;

-- Cleaning and transforming table data "consumption_percapita"

SELECT * from consumption_percapita
LIMIT 10;

ALTER TABLE consumption_percapita 
DROP COLUMN DATAFLOW,
DROP COLUMN OBS_FLAG;

UPDATE consumption_percapita
SET geo = substring(geo,4);
UPDATE consumption_percapita
SET freq = substring(freq,3);
UPDATE consumption_percapita
SET unit = 'KGOE';

ALTER TABLE consumption_percapita 
RENAME COLUMN geo TO country,
RENAME COLUMN TIME_PERIOD TO year,
RENAME COLUMN OBS_VALUE TO value;

-- DATA EXPLORATION
SELECT country, fuel_type, value from fuel_consumption
WHERE value = 0
GROUP bY country, fuel_type, value
ORDER BY country;

-- creating a table on the missing values per country. There are multiple countries where we have more than 3 fuel category missing, which can influence the results, especially where the "gas oil and diesel oil" cateory is missing.
-- However, for the sake of the project, I will work with the data I have.

SELECT country, GROUP_CONCAT(DISTINCT fuel_type), count(DISTINCT fuel_type) as missing_count from fuel_consumption
WHERE value = 0
GROUP bY country
ORDER BY missing_count;

-- Turns out, we already have a Total row. However, this total row doesn't seem to include the missing data for the countries. 

SELECT fuel_type, SUM(value) as total_EU_consummption FROM fuel_consumption
GROUP BY fuel_type
ORDER BY total_EU_consummption DESC;

SELECT fuel_type, country, year, value from fuel_consumption
WHERE fuel_type = 'Total'
GROUP BY fuel_type, country, year, value;

SELECT value from fuel_consumption
WHERE fuel_type = 'Total';

-- checking which countries has zero values for different fuel types

SELECT fuel_type, country, year, value,
(SELECT value FROM fuel_consumption WHERE fuel_type = 'Total') as total
FROM fuel_consumption;


CREATE VIEW energy.totalconsumption AS 
SELECT Time_frequency, fuel_type, unit, country, year, value,
CASE WHEN fuel_type = 'Total' THEN value END as total,
CASE 
	WHEN fuel_type = 'Primary solid biofuels' THEN 'Renewable'
	WHEN fuel_type = 'Ambient heat (heat pumps)' THEN 'Renewable'
	WHEN fuel_type = 'Solar thermal' THEN 'Renewable'
	ELSE 'Non-renewable'
END as renewable
FROM fuel_consumption
GROUP BY Time_frequency, fuel_type, unit, country, year, value;

SELECT * from totalconsumption
WHERE total IS NOT NULL;

DROP VIEW totalconsumption;
DROP VIEW renewables;


-- END OF TRIAL END ERROR

-- Creating a view for marking th renewable and non-reneawble energy sources. I also included the Total description to be able to differenctiate the Total rows from the rest. 

CREATE VIEW energy.renewables AS 
SELECT Time_frequency, fuel_type, unit, country, year, value,
CASE 
WHEN fuel_type = 'Primary solid biofuels' THEN 'Renewable'
WHEN fuel_type = 'Ambient heat (heat pumps)' THEN 'Renewable'
WHEN fuel_type = 'Solar thermal' THEN 'Renewable'
WHEN fuel_type = 'Total' THEN 'Total'
ELSE 'Non-renewable'
END as renewable
FROM fuel_consumption
GROUP BY Time_frequency, fuel_type, unit, country, year, value; 

SELECT * from renewables;

-- Analyzing the growth of renewable energy sources over the years in the EU
-- use of CTE function  

WITH all_re as (
	SELECT year, renewable, sum(value) as res
	FROM renewables
	WHERE renewable = 'renewable'
	GROUP BY year, renewable),
	total as (
	SELECT year, renewable, sum(value) as total
	FROM renewables
	WHERE renewable = 'Total'
	GROUP BY year, renewable)
SELECT renewables.year, res, total, ROUND(res/total*100,2) as re_percent FROM renewables 
JOIN all_re ON all_re.year = renewables.year
JOIN total ON total.year = renewables.year
GROUP BY renewables.year, res, total;

-- which country has the higherst renewable energy consumption

SELECT country, sum(value) as renewable_consumption from renewables
WHERE renewable = 'renewable'
GROUP BY country
ORDER BY renewable_consumption DESC;

SELECT country, sum(value) as nonrenewable_consumption from renewables
WHERE renewable = 'Non-renewable'
GROUP BY country
ORDER BY nonrenewable_consumption DESC;

-- Which country has the best ratio using renewables?

WITH all_re as (
	SELECT country, renewable, sum(value) as res
	FROM renewables
	WHERE renewable = 'renewable'
	GROUP BY country, renewable),
	total as (
	SELECT country, renewable, sum(value) as total
	FROM renewables
	WHERE renewable = 'Total'
	GROUP BY country, renewable)
SELECT renewables.country, res, total, ROUND(res/total*100,2) as re_percent FROM renewables 
JOIN all_re ON all_re.country = renewables.country
JOIN total ON total.country = renewables.country
GROUP BY renewables.country, res, total
ORDER BY re_percent DESC;

-- which fuel type is the most used in the selected countries (40) and in the EU

SELECT DISTINCT country from renewables
WHERE fuel_type <> 'Total' AND country <> 'European Union - 27 countries (from 2020)' ;

SELECT fuel_type, sum(value) as total from renewables
WHERE fuel_type <> 'Total' AND country <> 'European Union - 27 countries (from 2020)' AND year > 2019
GROUP BY fuel_type 
ORDER BY total DESC;

SELECT country, fuel_type, sum(value) as total from renewables
WHERE fuel_type <> 'Total' AND country = 'European Union - 27 countries (from 2020)' AND year > 2019
GROUP BY fuel_type 
ORDER BY total DESC;

-- which fuel source do countries use the most

SELECT country, fuel_type, sum(value) as total from renewables
WHERE fuel_type <> 'Total' AND country <> 'European Union - 27 countries (from 2020)' AND year > 2019
GROUP BY country, fuel_type 
ORDER BY country, total DESC;


-- ranking the fuel types for each country

SELECT (RANK() OVER(PARTITION BY country ORDER BY sum(value))) as ranking,
country, fuel_type, sum(value) as total from renewables
WHERE fuel_type <> 'Total' AND country <> 'European Union - 27 countries (from 2020)'
GROUP BY country, fuel_type
ORDER BY REVERSE(ranking) ASC;


































SELECT * from renewables;
SELECT * from consumption_quantity;

CREATE VIEW fuel_GWH AS (
SELECT *, value*11.63 as GWH from renewables);

SELECT fuel_GWH.*, c1.value from fuel_GWH
INNER JOIN consumption_quantity c1 
ON fuel_GWH.country = c1.country
AND fuel_GWH.year = c1.year
WHERE fuel_GWH.fuel_type = 'Total';
