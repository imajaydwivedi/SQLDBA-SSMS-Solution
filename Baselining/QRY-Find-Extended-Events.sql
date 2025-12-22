-- Find Extended Events for particular Keyword
SELECT  o.name AS event_name,
        o.description AS event_description,
        p.name AS package_name,
        p.description AS package_description
FROM sys.dm_xe_objects AS o
INNER JOIN sys.dm_xe_packages AS p ON o.package_guid = p.guid
WHERE o.object_type = 'event'
-- Optional: filter out internal/private events if needed
AND (o.capabilities IS NULL OR o.capabilities & 1 = 0)
AND (p.capabilities IS NULL OR p.capabilities & 1 = 0)
and o.description like '%error%'
ORDER BY event_name ASC;

