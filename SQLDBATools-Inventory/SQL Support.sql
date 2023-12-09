--	SQL Server Support LifeCycle
	--	https://support.microsoft.com/en-in/lifecycle/search/1044
	
--	https://www.brentozar.com/archive/2015/05/sql-server-version-detection/

SELECT	[version],
    common_version = SUBSTRING([version], 1, CHARINDEX('.', version) + 1 ),
    major = PARSENAME(CONVERT(VARCHAR(32), [version]), 4),
    minor = PARSENAME(CONVERT(VARCHAR(32), [version]), 3),
    build = PARSENAME(CONVERT(varchar(32), [version]), 2),
    revision = PARSENAME(CONVERT(VARCHAR(32), [version]), 1)
FROM (	SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)) AS [version] ) AS B

