Declare @JobId NVarchar(600)
Declare Cur Cursor For
Select job_id  --,j.name
from msdb..sysjobs_view as j
Where name not Like 'DBA%'
and name not in ('Nightly Maintenance','CommandLog Cleanup','Archive_Maintenance','sp_purge_jobhistory','Long Running Jobs Check','Backup Logs','Capture_blocking','sp_delete_backuphistory','syspolicy_purge_history')
and j.enabled = 1

Open Cur
Fetch Cur Into @JobId
	While @@FETCH_STATUS=0
		Begin
			EXEC msdb.dbo.sp_update_job @job_id=@JobId, @enabled=0
		Fetch Cur Into @JobId
		End
Close Cur
Deallocate Cur