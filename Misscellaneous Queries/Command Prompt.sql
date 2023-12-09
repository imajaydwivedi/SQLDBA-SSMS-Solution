--	1) Get files 
exec xp_cmdshell 'dir \\MyDbServerName\f$\dump\*Facebook_* /od /b '
/*
output
MyDbServerName_Facebook_LOG_20180323_000501.csq
MyDbServerName_Facebook_LOG_20180323_001500.csq
*/
