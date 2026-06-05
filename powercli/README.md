# PowerCLI Tools

Esta pasta contém scripts PowerShell para automação de infraestrutura VMware vSphere/ESXi com PowerCLI.

Cada script inclui descrição de uso e finalidade, ideal para tarefas de administração em vCenter e hosts ESXi.

## Requisitos

- PowerShell 5.0 ou superior
- PowerCLI 13.0 ou superior (instalação: `Install-Module -Name VMware.PowerCLI -Force`)
- Acesso autenticado a vCenter Server ou hosts ESXi

## Scripts

### `ESXI-add-NTP-DNS-DOMAIN.ps1`
**Finalidade:** Configurar NTP, DNS e domínio em hosts ESXi

**Uso:** Autentica-se em um host ESXi e configura:
- Servidores NTP para sincronização de tempo
- Servidores DNS para resolução de nomes
- Domínio DNS do host

**Exemplo:**
```powershell
.\ESXI-add-NTP-DNS-DOMAIN.ps1
```

---

### `active-ssh-esxi.ps1`
**Finalidade:** Ativar/desativar SSH nos hosts ESXi

**Uso:** Gerencia o serviço SSH (sshd) em hosts ESXi para fins de administração remota.

**Exemplo:**
```powershell
.\active-ssh-esxi.ps1
```

---

### `apply-resources-limits.ps1`
**Finalidade:** Aplicar limites de recursos (CPU, memória) em VMs

**Uso:** Define limites de CPU e/ou memória em máquinas virtuais para controle de recursos.

**Exemplo:**
```powershell
.\apply-resources-limits.ps1
```

---

### `get-alarms-infra.ps1`
**Finalidade:** Listar alarmes da infraestrutura vSphere

**Uso:** Recupera e exibe alarmes ativos ou recentes do vCenter/ESXi.

**Exemplo:**
```powershell
.\get-alarms-infra.ps1
```

---

### `get-cpu-cluster.ps1`
**Finalidade:** Obter informações de CPU por cluster

**Uso:** Lista estatísticas de CPU (total, utilizado, disponível) de todos os hosts em um cluster.

**Exemplo:**
```powershell
.\get-cpu-cluster.ps1
```

---

### `get-ha-status.ps1`
**Finalidade:** Verificar status de High Availability (HA) do cluster

**Uso:** Consulta e exibe o status de HA, número de slots, VMs protegidas, etc.

**Exemplo:**
```powershell
.\get-ha-status.ps1
```

---

### `get-mhz-vms-vcops.ps1`
**Finalidade:** Obter utilização de CPU em MHz para VMs via vCenter Operations Manager

**Uso:** Integra com vCops (se disponível) para coletar dados de performance de CPU em MHz.

**Exemplo:**
```powershell
.\get-mhz-vms-vcops.ps1
```

---

### `get-vcpus-cpu.ps1`
**Finalidade:** Obter informações de vCPU por host/cluster

**Uso:** Exibe cores físicos vs vCPUs alocadas em hosts ESXi.

**Exemplo:**
```powershell
.\get-vcpus-cpu.ps1
```

---

### `get-vm-port-interface-cdp.ps1`
**Finalidade:** Obter interface e porta de rede via CDP (Cisco Discovery Protocol)

**Uso:** Lista informações de conectividade de rede das VMs usando dados CDP do switch.

**Exemplo:**
```powershell
.\get-vm-port-interface-cdp.ps1
```

---

### `get-vm-portgroup.ps1`
**Finalidade:** Listar Port Groups associados às VMs

**Uso:** Exibe redes/port groups conectadas a cada máquina virtual.

**Exemplo:**
```powershell
.\get-vm-portgroup.ps1
```

---

### `remove-snapshot.ps1`
**Finalidade:** Remover snapshots de VMs

**Uso:** Deleta snapshots de máquinas virtuais (útil para limpeza e recuperação de espaço em disco).

**Exemplo:**
```powershell
.\remove-snapshot.ps1
```

---

### `send-telegram.ps1`
**Finalidade:** Enviar notificações via Telegram

**Uso:** Integra com o bot Telegram para enviar alertas/notificações sobre eventos da infraestrutura.

**Exemplo:**
```powershell
.\send-telegram.ps1
```

---

## Conectar ao vCenter/ESXi

Antes de executar qualquer script, conecte-se ao vCenter ou ESXi:

```powershell
# Conectar ao vCenter
Connect-VIServer -Server vcenter.example.com -User admin@vsphere.local -Password "senha"

# Conectar a um host ESXi
Connect-VIServer -Server esxi-host.example.com -User root -Password "senha"
```

## Desconectar

```powershell
Disconnect-VIServer -Confirm:$false
```

## Notas de Segurança

- Não armazene senhas em texto plano nos scripts
- Use credenciais armazenadas ou prompts interativos
- Teste scripts em ambientes não-produtivos primeiro
- Valide logs e saídas antes de executar em produção
