
/*	****************************************************************************
*	Find Drives not used by SQL Server
*	****************************************************************************/
-- Step 01: Find All drives where files are going
SELECT DISTINCT @@serverName as srvName, QUOTENAME(LEFT(physical_name,3),'''') AS DrivesUsed FROM sys.master_files AS mf;

--	Step 02: Add them in comma separated list in below PowerShell code
$Drivers = 'E:\', 'F:\', 'H:\', 'I:\', 'J:\', 'K:\', 'L:\', 'M:\', 'N:\', 'O:\', 'P:\', 'Q:\', 'R:\', 'V:\';
#$Drivers
Get-VolumeInfo -ComputerName DbServerName | Where-Object {$_.VolumeName -notin $Drivers} | Out-GridView;

	