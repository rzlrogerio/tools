# Load de current date
$t = Get-Date

$DOMAIN_NAME="your domain"

$DNS_1 = "first DNS server"
$DNS_2 = "second DNS server"

$NTP_1 = "first NTP server"
$NTP_2 = "second NTP server"
$NTP_3 = "third NTP server"

$ESXIS = @(Get-VMHost)

ForEach( $esxi in $ESXIS)
	{
	$dst = Get-VMHost $esxi | %{ Get-View $_.ExtensionData.ConfigManager.DateTimeSystem }
	$dst.UpdateDateTime((Get-Date($t.ToUniversalTime()) -format u))

	# set domain and DNS servers
	Get-VMHost $esxi | Get-VMHostNetwork | Set-VMHostNetwork -DomainName $DOMAIN_NAME -DNSAddress $DNS_1 , $DNS_2 -Confirm:$false

	# set ntp servers
	Get-VMHost $esxi | Add-VmHostNtpServer -NtpServer $NTP_1
	Get-VMHost $esxi | Add-VmHostNtpServer -NtpServer $NTP_2
	Get-VMHost $esxi | Add-VmHostNtpServer -NtpServer $NTP_3

	# restart and enable NTPD Service
	Get-VMHost $esxi | Get-VmHostService | Where-Object {$_.key -eq "ntpd"} | Restart-VMHostService -Confirm:$false
	Get-VMHost $esxi | Get-VmHostService | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
	}
