### Importando modulos necessarios
### Import the module - Powercli

& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Antes remove o arquivo anterior para ficar sempre atualizado
# Before, remove the files
rm $FILE_RELAT
rm $FILE_FINAL

$FILE_RELAT = "result-vcpus.csv"
$FILE_FINAL = "relatorio-ajuste.csv"

$result = @()

$vms = Get-view -ViewType VirtualMachine

foreach ($vm in $vms)
	{
    	 $obj = new-object psobject

   	 $obj | Add-Member -MemberType NoteProperty -Name ServerName -Value $vm.Name

    	 $obj | Add-Member -MemberType NoteProperty -Name CPUs -Value $vm.config.hardware.NumCPU

    	 $obj | Add-Member -MemberType NoteProperty -Name Sockets -Value ($vm.config.hardware.NumCPU/$vm.config.hardware.NumCoresPerSocket)

    	 $obj | Add-Member -MemberType NoteProperty -Name CPUPersocket -Value $vm.config.hardware.NumCoresPerSocket

    	 $result += $obj
    	}

$result | export-csv $FILE_RELAT

## Carregando a lista de servidores que precisam de ajustes baseada na saida por "cores per socket" do relatorio
## Load the server list for adjustment "cores per socket"

# LoadFile
$VALORES = @(Get-Content $FILE_RELAT)

ForEach ( $valor in $VALORES )
	{
	 $VM_NAME = $valor.Split(",")[0] | % { $_ -replace '"','' }

	 $PW_STATUS = Get-VM $VM_NAME | Select PowerState

	 write-host "$VM_NAME - $PW_STATUS"

	 if ( $PW_STATUS.PowerState -eq "PoweredOn" )
		{
		 $CORE_SOCKET = $valor.Split(",")[3] | % { $_ -replace '"','' }

		  if ( $CORE_SOCKET -gt 2 )
			{
			 echo "$VM_NAME precisa ajustar o CORE per SOCKET $CORE_SOCKET maior que o maximo 2" >> $FILE_FINAL 
			 #write-host "Eh maior que 2"
			}
		 else
			{
			 write-host "Eh menor que 2"
			}
		}
	}

