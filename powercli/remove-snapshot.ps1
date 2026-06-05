# Remove snapshot after 15 days

$remTask=Get-VM | Get-Snapshot | Where {$_.Created -lt (Get-Date).AddDays(-15)} | Remove-Snapshot -Confirm:$false
Wait-Task -Task $remTask
