$file = 'C:\Windows\System32\drivers\etc\hosts'

$file_content = Get-Content $file

foreach($line in $file_content) {
    if(-not [string]::IsNullOrEmpty($line.Trim())) {
        if($line -match "^(?<ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(?<hostname>[a-zA-Z_0-9-]*)$") {        
            $ip = $Matches['ip']
            $hostName = $Matches['hostname']

            #Write-Host "$hostName => $ip"
            $command = @"

Add-DnsServerResourceRecordA -Name "$hostName" -ZoneName "Contso.com" -AllowUpdateAny -IPv4Address "$ip"
"@;
            if (-not ($hostName -in @('host','dc'))) {
                $command
            }
        }
    }
}

/*
help Add-DnsServerResourceRecordA
Get-DnsServerResourceRecord -ZoneName "contso.com"
Add-DnsServerResourceRecordA -Name "Win10" -ZoneName "Contso.com" -AllowUpdateAny -IPv4Address "192.168.0.105"
*/