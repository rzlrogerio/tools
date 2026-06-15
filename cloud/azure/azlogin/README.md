# azlogin - Gerenciador de Credenciais AKS Azure

Script automatizado para gerenciar e registrar credenciais de clusters AKS (Azure Kubernetes Service) no kubeconfig local.

## ⚠️ IMPORTANTE - BACKUP OBRIGATÓRIO

**ANTES DE USAR ESTE SCRIPT, FAÇA BACKUP DO SEU ARQUIVO `~/.kube/config`!**

```bash
# Crie um backup manual do seu config atual
cp ~/.kube/config ~/.kube/config.backup-$(date +%Y%m%d-%H%M%S)
```

O script manipula os arquivos de configuração do kubectl e, embora tenha mecanismos de segurança, **é essencial ter um backup manual antes da primeira execução**.

## 📋 Pré-requisitos

O script requer as seguintes ferramentas instaladas:

- **Azure CLI** (`az`)
- **kubectl**
- **fzf** (fuzzy finder para seleção interativa)
- **kubectx** (opcional, usado ao final para limpar contexto)

### Instalação das dependências no Ubuntu/Debian:

```bash
# fzf
sudo apt install fzf

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# kubectx (opcional)
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
```

## 🚀 Uso

### Execução básica:

```bash
./azlogin
```

### Fluxo de operação:

1. O script lista todas as subscriptions do Azure disponíveis
2. Permite seleção interativa de uma ou múltiplas subscriptions usando `fzf`
   - Use **TAB** para seleção múltipla
   - Use **ENTER** para confirmar
3. Para cada subscription selecionada:
   - Lista todos os clusters AKS
   - Registra as credenciais no kubeconfig
   - Evita duplicações
4. Ao final, exibe um resumo dos clusters processados

## 🔧 Como Funciona

### Lógica do Script

O script segue esta sequência de operações:

#### 1. Verificação de Dependências
Valida se todas as ferramentas necessárias estão instaladas antes de prosseguir.

#### 2. Gerenciamento de Backup Automático

**IMPORTANTE:** O script gerencia automaticamente dois arquivos:
- `~/.kube/config` - Arquivo principal do kubectl
- `~/.kube/config-azure` - Backup automático criado pelo script

**Funcionamento do backup automático:**

```bash
# ANTES de processar (getOldBackup):
# Move config-azure de volta para config
# Isso restaura o estado anterior e evita duplicações
mv ~/.kube/config-azure ~/.kube/config

# DEPOIS de processar (saveNewVersion):
# Salva o novo estado como backup
cp ~/.kube/config ~/.kube/config-azure
```

**⚠️ ATENÇÃO:** O backup automático (`config-azure`) é sobrescrito a cada execução. Por isso é **CRÍTICO** fazer um backup manual antes da primeira execução!

#### 3. Seleção de Subscriptions
- Carrega todas as subscriptions do Azure
- Apresenta interface interativa com `fzf`
- Permite seleção múltipla para processar várias subscriptions de uma vez

#### 4. Processamento de Clusters AKS
Para cada subscription selecionada:
- Define a subscription ativa no Azure CLI
- Lista todos os clusters AKS
- Para cada cluster:
  - Verifica se já foi processado nesta execução (evita duplicação)
  - Verifica se já existe no kubeconfig
  - Registra credenciais usando `az aks get-credentials`

#### 5. Prevenção de Duplicações
O script usa um array associativo para rastrear clusters já processados e verifica se o contexto já existe no kubeconfig, evitando cadastros duplicados.

#### 6. Limpeza Final
Ao terminar, executa `kubectx -u` para limpar o contexto atual do kubectl.

## 📊 Exemplo de Saída

```
Carregando subscriptions...

[Interface fzf para seleção]

==========================================
Iniciando processamento das subscriptions selecionadas
==========================================

===> Processando Subscription: Produção
     ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  → Registrando AKS: prod-cluster-01 (Resource Group: rg-prod)
  ✓ AKS já cadastrado no kubeconfig: prod-cluster-02 (Resource Group: rg-prod)

===> Processando Subscription: Desenvolvimento
     ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
  → Registrando AKS: dev-cluster-01 (Resource Group: rg-dev)

==========================================
✓ Processamento concluído!
==========================================

Total de AKS processados: 3

Clusters AKS disponíveis:
dev-cluster-01
prod-cluster-01
prod-cluster-02
```

## 🔐 Segurança

- O script não modifica recursos no Azure, apenas lê informações
- Credenciais são gerenciadas pela Azure CLI
- O arquivo kubeconfig é atualizado localmente
- Backup automático é criado a cada execução em `~/.kube/config-azure`
- **SEMPRE mantenha um backup manual adicional antes da primeira execução**

## 🐛 Troubleshooting

### Erro: "fzf não está instalado"
```bash
sudo apt install fzf
```

### Erro: "Azure CLI não está instalado"
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Erro: "kubectl não está instalado"
Siga as instruções de instalação do kubectl na seção de pré-requisitos.

### Nenhuma subscription encontrada
Certifique-se de estar autenticado no Azure:
```bash
az login
az account list
```

### Recuperar backup manual
Se algo der errado, restaure seu backup manual:
```bash
# Restaurar backup manual
cp ~/.kube/config.backup-YYYYMMDD-HHMMSS ~/.kube/config

# Verificar contextos
kubectl config get-contexts
```

### Restaurar o backup automático
Se precisar voltar ao estado da última execução:
```bash
# O backup automático está em
cp ~/.kube/config-azure ~/.kube/config
```

## 📝 Notas

- O script foi otimizado para evitar loops desnecessários e melhorar a performance
- A seleção via `fzf` permite processar apenas as subscriptions desejadas
- Clusters já cadastrados são identificados e não são reprocessados
- O script mantém um histórico da execução atual para evitar duplicações

## 🔄 Fluxo de Arquivos

```
Execução do script:
1. Backup automático: config-azure → config (restaura estado anterior)
2. Processamento: adiciona novos clusters ao config
3. Novo backup: config → config-azure (salva novo estado)

Recomendação:
- Backup manual inicial: config → config.backup-YYYYMMDD-HHMMSS
```

## 📞 Suporte
Chama o "batima" :)

