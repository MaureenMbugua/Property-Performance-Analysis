-- Create view valid_lease_flag that can be reused in subsequent queries
CREATE VIEW leases_valid_flag AS
SELECT 
    *,
    CASE 
        WHEN (start_date < end_date OR (end_date IS NULL AND start_date <= CURDATE())) 
        THEN 1 
        ELSE 0 
    END AS valid_lease
FROM leases;

-- Query 1: Occupancy Underperformers
WITH occupancy AS (
    SELECT 
        p.id AS property_id,
        p.name AS property_name,
        COUNT(DISTINCT u.id) AS total_units,
        COUNT(DISTINCT CASE 
            WHEN l.valid_lease = 1 THEN u.id 
        END) AS occupied_units
    FROM properties p
    LEFT JOIN units u ON p.id = u.property_id
    LEFT JOIN leases_valid_flag l ON u.id = l.unit_id
    GROUP BY p.id, p.name
)
SELECT 
    property_id,
    property_name,
    ROUND((occupied_units / total_units) * 100, 2) AS occupancy_rate
FROM occupancy
WHERE (occupied_units / total_units) * 100 < 80;

-- Query 2: Arrears by Location

SELECT 
    l.name AS location_name,
    SUM(ls.arrears) AS total_arrears
FROM locations l
LEFT JOIN properties p ON p.location_id = l.id
LEFT JOIN units u ON u.property_id = p.id
LEFT JOIN leases_valid_flag ls 
    ON ls.unit_id = u.id AND ls.valid_lease = 1
GROUP BY l.name
ORDER BY total_arrears DESC;

-- Query 3: Collection Efficiency Leaderboard

SELECT 
    p.id AS property_id,
    p.name AS property_name,
    ROUND((1 - (SUM(ls.arrears) / NULLIF(SUM(ls.rent_per_month), 0))) * 100, 2) AS collection_efficiency
FROM leases_valid_flag ls
JOIN units u ON ls.unit_id = u.id
JOIN properties p ON u.property_id = p.id
WHERE ls.valid_lease = 1
GROUP BY p.id, p.name
ORDER BY collection_efficiency DESC
LIMIT 3;

-- Query 4: Data Quality Check – Invalid Leases

SELECT 
    l.id AS lease_id,
    p.name AS property_name,
    u.name AS unit_name,
    t.name AS tenant_name,
    CASE 
        WHEN l.rent_per_month < 0 THEN 'NEGATIVE_RENT'
        WHEN l.end_date < l.start_date THEN 'END_BEFORE_START'
    END AS reason_flag
FROM leases l
JOIN units u ON l.unit_id = u.id
JOIN properties p ON u.property_id = p.id
JOIN tenants t ON l.tenant_id = t.id
WHERE 
    l.rent_per_month < 0 
    OR l.end_date < l.start_date;
    
-- Query 5: Multi-Unit Tenants

SELECT 
    t.name AS tenant_name,
    COUNT(DISTINCT u.id) AS unit_count,
    GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ', ') AS properties
FROM leases_valid_flag ls
JOIN tenants t ON ls.tenant_id = t.id
JOIN units u ON ls.unit_id = u.id
JOIN properties p ON u.property_id = p.id
WHERE ls.valid_lease = 1
GROUP BY t.id, t.name
HAVING COUNT(DISTINCT u.id) >= 2;

