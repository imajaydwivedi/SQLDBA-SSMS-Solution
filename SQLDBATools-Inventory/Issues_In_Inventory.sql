USE SQLDBATools
GO

/*	Issue 01) Server with incomplete information	*/
select *
from Info.Server
where OperatingSystem is null
-- 8 out of 176

/*	Issue 02) Server not having Application information */
SELECT s.ServerName, a.* -- Check where Application details are null
FROM Info.Server as s
left join [info].[Xref_ApplicationServer] as a
  on a.FQDN = s.FQDN
ORDER BY ApplicationID
--	100 Servers out of 163 servers

/*	Issue 03) Servers for which SQLInstanceInfo collection failed */
SELECT s.*, i.InstanceCounts -- Check for InstanceCounts = 0
FROM Info.Server as s
OUTER APPLY
	( SELECT COUNT(i.InstanceName) AS InstanceCounts FROM info.Instance as i WHERE i.FQDN = s.FQDN) as i
where InstanceCounts = 0
--	40 Servers out of 163 servers

/*	Issue 04) Armus Domain Server Credentials	*/

/*	Issue 05) Commands failing */
select * from [Staging].[CollectionErrors]

/*	Issue 06) Supported Servers yet not present in Inventory */
select * from [dbo].[ExcelSheetServers] as s where not exists (select * from Info.Server as i where i.ServerName like ('%'+s.Name+'%') )


select * from Info.Instance
select * from [dbo].[ExcelSheetServers] e 
	where e.Domain <> 'contso.com'
--	(22 rows affected)

