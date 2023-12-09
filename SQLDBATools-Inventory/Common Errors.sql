/* 01)	Get-WmiObject : The RPC server is unavailable. (Exception from HRESULT: 0x800706BA)
		Get-WmiObject : The RPC server is too busy to complete this operation. (Exception from HRESULT: 0x800706BB)
*/
--	https://stackoverflow.com/questions/11330874/get-wmiobject-the-rpc-server-is-unavailable-exception-from-hresult-0x800706
--	https://blog.netspi.com/powershell-remoting-cheatsheet/
netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes