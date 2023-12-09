# To get the PID of the process (this will give you the first occurrance if multiple matches)
$proc_pid = (get-process "slack").Id[0]

# To match the CPU usage to for example Process Explorer you need to divide by the number of cores
$cpu_cores = (Get-WMIObject Win32_ComputerSystem).NumberOfLogicalProcessors

# This is to find the exact counter path, as you might have multiple processes with the same name
$proc_path = ((Get-Counter "\Process(*)\ID Process").CounterSamples | ? {$_.RawValue -eq $proc_pid}).Path

# We now get the CPU percentage
$prod_percentage_cpu = [Math]::Round(((Get-Counter ($proc_path -replace "\\id process$","\% Processor Time")).CounterSamples.CookedValue) / $cpu_cores)