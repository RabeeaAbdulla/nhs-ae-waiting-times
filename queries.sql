-- NHS A&E waiting times: SQL queries (BigQuery)
-- Tables: nhs-ae-project.nhs_ae.ae_march, ae_oct, ae_dec
-- Type 1 = major hospital emergency departments (open 24 hours)
-- % seen within 4 hours = 100 * (1 - over 4 hrs / attendances)
-- The TOTAL row is England's total, so it is left out when adding up hospitals.


-- 1. England total, March 2026 (TOTAL row)
SELECT
  `A&E attendances Type 1` AS attendances,
  `Attendances over 4hrs Type 1` AS over_4hrs,
  ROUND(100 * (1 - `Attendances over 4hrs Type 1` / `A&E attendances Type 1`), 1) AS pct_within_4hrs
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` = 'TOTAL';


-- 2. Ten slowest hospitals on the 4-hour measure, March 2026
-- Hospitals with no Type 1 department are left out (division by zero).
SELECT
  `Org name` AS hospital,
  `A&E attendances Type 1` AS attendances,
  `Attendances over 4hrs Type 1` AS over_4hrs,
  ROUND(100 * (1 - `Attendances over 4hrs Type 1` / `A&E attendances Type 1`), 1) AS pct_within_4hrs
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` != 'TOTAL'
  AND `A&E attendances Type 1` > 0
ORDER BY pct_within_4hrs ASC
LIMIT 10;


-- 3. Regions: add up first, then calculate the %
SELECT
  `Parent Org` AS region,
  SUM(`A&E attendances Type 1`) AS attendances,
  SUM(`Attendances over 4hrs Type 1`) AS over_4hrs,
  ROUND(100 * (1 - SUM(`Attendances over 4hrs Type 1`) / SUM(`A&E attendances Type 1`)), 1) AS pct_within_4hrs
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` != 'TOTAL'
GROUP BY region
ORDER BY pct_within_4hrs ASC;


-- 4. Most 12+ hour waits for a bed (counts), top 10
SELECT
  `Org name` AS hospital,
  `Patients who have waited 12+ hrs from DTA to admission` AS waited_12hrs
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` != 'TOTAL'
ORDER BY waited_12hrs DESC
LIMIT 10;


-- 5. 12+ hour waits per 1,000 attendances (fair comparison), top 10
-- Note: the 12+ hour column covers all A&E types, but the divisor is Type 1 only.
SELECT
  `Org name` AS hospital,
  `A&E attendances Type 1` AS attendances,
  `Patients who have waited 12+ hrs from DTA to admission` AS waited_12hrs,
  ROUND(1000 * `Patients who have waited 12+ hrs from DTA to admission` / `A&E attendances Type 1`, 1) AS per_1000
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` != 'TOTAL'
  AND `A&E attendances Type 1` > 0
ORDER BY per_1000 DESC
LIMIT 10;


-- 6. Data quality check, March 2026
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(`A&E attendances Type 1` IS NULL) AS blank_attendances,
  COUNTIF(`Attendances over 4hrs Type 1` IS NULL) AS blank_over_4hrs,
  COUNTIF(`Attendances over 4hrs Type 1` > `A&E attendances Type 1`) AS impossible_rows,
  COUNTIF(`A&E attendances Type 1` = 0 AND `Org name` != 'TOTAL') AS no_type1_department
FROM `nhs-ae-project.nhs_ae.ae_march`;


-- 7. Dashboard table: all Type 1 hospitals, March 2026 (121 rows)
SELECT
  `Org name` AS hospital,
  `Parent Org` AS region,
  `A&E attendances Type 1` AS attendances,
  `Attendances over 4hrs Type 1` AS over_4hrs,
  ROUND(100 * (1 - `Attendances over 4hrs Type 1` / `A&E attendances Type 1`), 1) AS pct_within_4hrs,
  `Patients who have waited 12+ hrs from DTA to admission` AS waited_12hrs,
  ROUND(1000 * `Patients who have waited 12+ hrs from DTA to admission` / `A&E attendances Type 1`, 1) AS per_1000
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` != 'TOTAL'
  AND `A&E attendances Type 1` > 0
ORDER BY pct_within_4hrs ASC;


-- 8. Trend: England, October 2025, December 2025, March 2026 (UNION ALL stacks the tables)
SELECT 1 AS month_order, 'Oct 2025' AS month,
  `A&E attendances Type 1` AS attendances,
  `Attendances over 4hrs Type 1` AS over_4hrs,
  ROUND(100 * (1 - `Attendances over 4hrs Type 1` / `A&E attendances Type 1`), 1) AS pct_within_4hrs
FROM `nhs-ae-project.nhs_ae.ae_oct`
WHERE `Org name` = 'TOTAL'
UNION ALL
SELECT 2, 'Dec 2025',
  `A&E attendances Type 1`,
  `Attendances over 4hrs Type 1`,
  ROUND(100 * (1 - `Attendances over 4hrs Type 1` / `A&E attendances Type 1`), 1)
FROM `nhs-ae-project.nhs_ae.ae_dec`
WHERE `Org name` = 'TOTAL'
UNION ALL
SELECT 3, 'Mar 2026',
  `A&E attendances Type 1`,
  `Attendances over 4hrs Type 1`,
  ROUND(100 * (1 - `Attendances over 4hrs Type 1` / `A&E attendances Type 1`), 1)
FROM `nhs-ae-project.nhs_ae.ae_march`
WHERE `Org name` = 'TOTAL'
ORDER BY month_order;


-- 9. JOIN: change per hospital, October to March (matched on Org Code)
SELECT
  m.`Org name` AS hospital,
  m.`Parent Org` AS region,
  ROUND(100 * (1 - o.`Attendances over 4hrs Type 1` / o.`A&E attendances Type 1`), 1) AS oct_pct,
  ROUND(100 * (1 - m.`Attendances over 4hrs Type 1` / m.`A&E attendances Type 1`), 1) AS mar_pct,
  ROUND(
    (100 * (1 - m.`Attendances over 4hrs Type 1` / m.`A&E attendances Type 1`))
    - (100 * (1 - o.`Attendances over 4hrs Type 1` / o.`A&E attendances Type 1`)), 1) AS change_points
FROM `nhs-ae-project.nhs_ae.ae_oct` AS o
JOIN `nhs-ae-project.nhs_ae.ae_march` AS m
  ON o.`Org Code` = m.`Org Code`
WHERE m.`Org name` != 'TOTAL'
  AND o.`A&E attendances Type 1` > 0
  AND m.`A&E attendances Type 1` > 0
ORDER BY change_points DESC;
