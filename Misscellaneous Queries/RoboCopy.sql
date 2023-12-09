--	https://www.computerhope.com/robocopy.htm
--	https://stackoverflow.com/questions/40744335/how-do-i-force-robocopy-to-overwrite-files
--	https://stackoverflow.com/a/40750265

--	Copy single file named 'ACTIONSHEET_DATA_20180321.csq' from source folder to destination folder
robocopy \\SRCServer\I$\Backup \\DestinationServer\f$\Somefolder\Full_Backups Galaxy_DATA_20180815.csq
robocopy \\SRCServer\I$\pssdiag_Output_June06_Ajay "E:\Galaxy Issue\Replication_PSSDiag_Output" GalaxyServer__0125AM_to_0205AM_CST.zip

robocopy \\SRCServer\C$\DBA\SQLTrace E:\PerformanceAnalysis\Galaxy_Publisher_Baseline\SQLTrace SomeFile.zip
robocopy \\SRCServer\C$\DBA\SQLTrace \\DestinationServer\G$\DBA\SQLTrace SomeFile.trc
robocopy \\SRCServer\G$\DBA\SQLTrace E:\PerformanceAnalysis\Galaxy_Publisher_Baseline\SQLTrace SomeFile.zip

robocopy src dst sample.txt /is      # copy if attributes are equal
robocopy src dst sample.txt /it      # copy if attributes differ
robocopy src dst sample.txt /is /it  # copy irrespective of attributes


Step 01 - Copy Dbs Required by Job [Restore YouTubeMusicProdcopy DB from production]
robocopy \\SRCServer\F$\dump\db01\ v:\dump\DB02_dump\ "YouTubeMusicAuthority-data.DMP" "YouTubeMusicMore-data.DMP" "YouTubeMusic-data.DMP" "EntryAggregation-data.DMP" "VestaMusicProcessing-data.DMP"

Step 02 - Copy All Dbs Except Step 01
robocopy \\SRCServer\F$\dump\db01\ v:\dump\DB02_dump\ *-data.DMP /XF "YouTubeMusicAuthority-data.DMP" "YouTubeMusicMore-data.DMP" "YouTubeMusic-data.DMP" "EntryAggregation-data.DMP" "VestaMusicProcessing-data.DMP"

--	Copy all files of extension *.csql from source folder to destination
robocopy \\SourceServer\F$\dump\ I:\Backups\CW\Logs\ *.csq /is

robocopy SourcePath DestinationPath FileFullName /it /zb

-- Copy all files/folders including Empty directories
Robocopy /S /E  \\SourceDbServer\F:\AllProd F:\AllProd /MT