cls  

$CLUSTER = "CLUsTER_NAME"

$objReport = @()  
  
function Get-CDP    {  
    $obj = @()  
    Get-Cluster $CLUSTER | Get-VMHost  | Where-Object {$_.State -eq "Connected"} | %{Get-View $_.ID} |  
    %{$esxname = $_.Name; Get-View $_.ConfigManager.NetworkSystem} |  
    %{ foreach($physnic in $_.NetworkInfo.Pnic){  
      
        $obj = "" | Select-Object hostname, pNic,PortId,Address,vlan          
      
        $pnicInfo = $_.QueryNetworkHint($physnic.Device)  
        foreach($hint in $pnicInfo){  
          #Write-Host "$esxname $($physnic.Device)"  
          $obj.hostname = $esxname  
          $obj.pNic = $physnic.Device  
          if( $hint.ConnectedSwitchPort ) {  
            # $hint.ConnectedSwitchPort  
            $obj.PortId = $hint.ConnectedSwitchPort.PortId  
          } else {  
            # Write-Host "No CDP information available."; Write-Host  
            $obj.PortId = "No CDP information available."  
          }  
          $obj.Address = $hint.ConnectedSwitchPort.Address  
          $obj.vlan = $hint.ConnectedSwitchPort.vlan  
            
        }  
        $objReport += $obj  
      }  
    }  
$objReport  
}  
  
$results = get-cdp  
$results |  Export-Csv "PORT-$CLUSTER.csv"  

