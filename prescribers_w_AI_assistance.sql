--Which specialty has the highest prescription cost per day? Which has the lowest?


 (Select 'Highest'  as Rank, p.specialty_description, sum(pr.total_drug_cost)/sum(pr.total_day_supply) as cost_per_day
 from Prescriber as p join prescription as pr using(npi)
 Group by p.specialty_description
 order by cost_per_day desc 
 limit 1)

UNION ALL

 (Select 'Lowest', p.specialty_description, sum(pr.total_drug_cost)/sum(pr.total_day_supply) as cost_per_day
 from Prescriber as p join prescription as pr using(npi)
 Group by p.specialty_description
 order by cost_per_day Asc 
 limit 1)

--CLAUDE CODE--

 WITH specialty_cost AS (
    SELECT
        p.specialty_description,
        SUM(rx.total_drug_cost) / NULLIF(SUM(rx.total_day_supply), 0) AS cost_per_day
    FROM prescriber AS p
    JOIN prescription AS rx
        ON p.npi = rx.npi
    GROUP BY p.specialty_description
)
(SELECT 'Highest' AS rank_type, specialty_description, ROUND(cost_per_day::numeric, 2) AS cost_per_day
 FROM specialty_cost
 ORDER BY cost_per_day DESC NULLS LAST
 LIMIT 1)
UNION ALL
(SELECT 'Lowest', specialty_description, ROUND(cost_per_day::numeric, 2)
 FROM specialty_cost
 ORDER BY cost_per_day ASC NULLS LAST
 LIMIT 1);

---How many providers are assigned to each specialty.

 SELECT
    specialty_description,
    COUNT(DISTINCT npi) AS provider_count
FROM prescriber
GROUP BY specialty_description
ORDER BY provider_count DESC;

--Next, add an additional "TRUE/FALSE" column that states if that specialty has written any prescriptions.

SELECT
    p.specialty_description, COUNT(DISTINCT p.npi)  AS provider_count,
    CASE
        WHEN COUNT(rx.npi) > 0 THEN TRUE
        ELSE FALSE
    END AS has_written_prescriptions
FROM prescriber AS p
LEFT JOIN prescription AS rx
    ON p.npi = rx.npi
GROUP BY p.specialty_description
ORDER BY provider_count desc;

---Cluaude code

SELECT
    p.specialty_description,
    COUNT(DISTINCT p.npi)  AS provider_count,
    COUNT(rx.npi) > 0      AS has_prescriptions
FROM prescriber AS p
LEFT JOIN prescription AS rx
    ON p.npi = rx.npi
GROUP BY p.specialty_description
ORDER BY provider_count DESC;

--Finally, find the specialty that has written a prescription with the most providers. Then find the specialty with the most providers where none has written a prescription.

 (SELECT 'Most providers – has prescriptions' as Most_providers,
    p.specialty_description,
    COUNT(DISTINCT p.npi) AS provider_count
FROM prescriber AS p
JOIN prescription AS rx
    ON p.npi = rx.npi
GROUP BY p.specialty_description
ORDER BY provider_count DESC
LIMIT 1)
UNION ALL

(SELECT 'Most providers – has no prescriptions',
    p.specialty_description,
    COUNT(DISTINCT p.npi) AS provider_count
FROM prescriber AS p
LEFT JOIN prescription AS rx
    ON p.npi = rx.npi
GROUP BY p.specialty_description
HAVING COUNT(rx.npi) = 0
ORDER BY provider_count DESC
LIMIT 1);


--claude code
WITH specialty_summary AS (
    SELECT
        p.specialty_description,
        COUNT(DISTINCT p.npi)  AS provider_count,
        COUNT(rx.npi) > 0      AS has_prescriptions
    FROM prescriber AS p
    LEFT JOIN prescription AS rx
        ON p.npi = rx.npi
    WHERE p.specialty_description IS NOT NULL
    GROUP BY p.specialty_description
),
ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY has_prescriptions
                     ORDER BY provider_count DESC) AS rnk
    FROM specialty_summary
)
SELECT
    CASE WHEN has_prescriptions
         THEN 'Most providers – has prescriptions'
         ELSE 'Most providers – no prescriptions'
    END AS category,
    specialty_description,
    provider_count
FROM ranked
WHERE rnk = 1
ORDER BY has_prescriptions DESC;

-- Was the verification step able to tell you which queries Claude was confident in? 
--Yes

-- Was Claude able to match your code for each of these?
--the codes didnt match but the results were similar

-- Read the Prescriber_Methodology section on bene_count (Page 5). It will describe the limitations on available data.

-- Are we able to find which prescribers who have written prescriptions for a drug to only a single beneficiary?
--No. The data can't tell you which prescribers wrote a drug for only one beneficiary

-- Does Claude provide a query?
--yes
-- Did the verification step confirm confidence? yes

SELECT COUNT(*) AS rows_with_one_beneficiary
FROM prescription
WHERE bene_count = 1;   -- returns 0


--PART 2--


-- Write a query to get a list of each distinct generic_name on the drug table (1727 distinct drugs). -- THE CORRECT ANS IS 1787
SELECT DISTINCT generic_name
FROM drug
ORDER BY generic_name;

SELECT COUNT(DISTINCT generic_name) AS distinct_generic_names
FROM drug;

-- Save this output as a .csv
-- Provide Claude with this .csv
-- Ask Claude to categorize these drugs into 10 or fewer categories and provide you with a csv. If it wants an API key, just say you only want a .csv with each generic_name and which category in which it belongs. (This step will take some time. Make a coffee. ~5 mins)
-- Download the csv

---Part 3
-- Ask Claude how you can incorporate your csv into the prescribers database. Follow the directions to create a table and load the .csv.
CREATE TABLE drug_category (
    generic_name TEXT PRIMARY KEY,
    category     TEXT NOT NULL
);

SELECT DISTINCT d.generic_name
FROM drug AS d
LEFT JOIN drug_category AS dc
    ON d.generic_name = dc.generic_name
WHERE dc.generic_name IS NULL;

-- Write a query that uses the table you just created to find out the total_day_supply and total_cost(in money) for each specialty/drug_category combination that has results.


WITH drug_cat AS (
    -- one category per drug_name so costs aren't double-counted
    SELECT
        d.drug_name,
        MIN(dc.category) AS category
    FROM drug AS d
    JOIN drug_category AS dc
        ON d.generic_name = dc.generic_name
    GROUP BY d.drug_name
)
SELECT
    p.specialty_description,
    c.category                         AS drug_category,
    SUM(rx.total_day_supply)           AS total_day_supply,
    SUM(rx.total_drug_cost)::MONEY     AS total_cost
FROM prescription AS rx
JOIN prescriber AS p
    ON p.npi = rx.npi
JOIN drug_cat AS c
    ON c.drug_name = rx.drug_name
GROUP BY
    p.specialty_description,
    c.category
ORDER BY
    p.specialty_description,
    total_cost DESC;

--Now, describe the new table you created to Claude and ask it to provide you with a query the provided the same result.
WITH drug_to_category AS (
    SELECT d.drug_name,
           MIN(dc.category) AS category     
    FROM drug AS d
    JOIN drug_category AS dc
      ON dc.generic_name = d.generic_name
    GROUP BY d.drug_name
)
SELECT p.specialty_description,
       dtc.category,
       SUM(rx.total_day_supply)              AS total_day_supply,
       SUM(rx.total_drug_cost)::money        AS total_drug_cost
FROM prescription AS rx
JOIN prescriber AS p
  ON p.npi = rx.npi
JOIN drug_to_category AS dtc
  ON dtc.drug_name = rx.drug_name
GROUP BY p.specialty_description, dtc.category
ORDER BY p.specialty_description, dtc.category;

--Did the results match?

YES