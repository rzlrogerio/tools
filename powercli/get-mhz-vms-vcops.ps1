#!/bin/sh

### Importando modulos necessarios
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Syslog
Import-Module "C:\scripts\vcops\metricas\send-syslog.ps1"

# Criando o objeto para enviar os logs

$GRAYLOG = "seu graylog"
$GRAYLOG_TCP_PORT = "6060"
$GRAYLOG_UDP_PORT = "6061" 
 
$SYSLOG = SyslogSender $GRAYLOG $GRAYLOG_UDP_PORT

$PERIODO = "5"

$CONTROL = $null
$SAIR = "C:\scripts\vcops\metricas\locks\control-mhz-vm.sair"

while ($CONTROL -ceq $null)
	{
	 # Para fazer sair
         if (Test-Path $SAIR)
                {
                 echo "File $SAIR existe, saindo"
                 exit
                }

	 # controle de fluxo
	 $LOCK = "C:\scripts\vcops\metricas\locks\control-mhz-vm.lck"

	 if (Test-Path $LOCK)
		{
	 	 echo "Lock file found! Saindo"
	 	 exit
		}
	 else
		{
         	 # Criamos o arquivo de lock
         	 echo " " > $LOCK

	 	 # Connect no vCOPS
	 	 Connect-OMServer vcops.seudom -User apiuser -Password suasenha
	 	 Connect-VIServer vcenter.seudom -User svc-zbx-vcenter-ro@pci.intra -Password Z3X*vcR0

	 	 # Lista de VMS alvo da coleta
	 	 #$VMS = @(Get-Cluster BI | Get-VM)
	 	 $VMS = @(Get-VM)

	 	 ForEach( $VM in $VMS )
			{
		 	 $VL_MHZ_AVG = Get-OMStat -Resource $VM.Name -Key "cpu|usagemhz_average" -IntervalType 'Minutes' -IntervalCount $PERIODO -RollupType 'Avg' -From ([DateTime]::Now).AddMinutes(-$PERIODO)
 
        	 	 $RESOURCE_MHZ_AVG 	= $VL_MHZ_AVG.Resource
	         	 $KEY_MHZ_AVG 		= "MHZ_AVG"
	         	 $VALUE_MHZ_AVG 	= $VL_MHZ_AVG.Value
	         	 $TIME_MHZ_AVG 		= $VL_MHZ_AVG.Time

		 	 #$MSG_AVG 		= "graylog_30", "VM_MHZ_AVG $RESOURCE_MHZ_AVG", "VALUE_MHZ $VALUE_MHZ_AVG", "TIME_MHZ $TIME_MHZ_AVG"
		 	 $MSG_AVG 		= "VM_MHZ_AVG $RESOURCE_MHZ_AVG", "VALUE_MHZ $VALUE_MHZ_AVG", "TIME_MHZ $TIME_MHZ_AVG"
	
	         	 write-host $MSG_AVG

		 	 $SYSLOG.Send("$MSG_AVG")
			}

			 Disconnect-OMServer * -confirm:$false
			 Disconnect-VIServer * -confirm:$false

			 rm $LOCK
		}
	}

