SELECT	sm.object_id
        , ss.[name] as [schema]
        , o.[name] as object_name
        , o.[type]
        , o.[type_desc]
        --, [definition] AS [definition(x)] FOR XML PATH('')
		,convert(xml,( select [definition] FOR XML PATH ('Query') ))
FROM sys.sql_modules AS sm     
JOIN sys.objects AS o 
    ON sm.object_id = o.object_id  
JOIN sys.schemas AS ss
    ON o.schema_id = ss.schema_id  
WHERE o.[name] = 'sp_WhoIsActive'
ORDER BY 
      o.[type]
    , ss.[name]
    , o.[name];