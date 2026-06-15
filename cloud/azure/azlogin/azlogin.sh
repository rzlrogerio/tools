#!/bin/bash -
#===============================================================================
#
#          FILE: azlogin
#
#         USAGE: ./azlogin
#
#   DESCRIPTION: Gerencia credenciais de clusters AKS do Azure
#
#       OPTIONS: ---
#  REQUIREMENTS: az cli, kubectl, fzf
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (),
#  ORGANIZATION:
#       CREATED: 11/07/2025 14:27
#      REVISION:  ---
#===============================================================================


set -o nounset  # Treat unset variables as an error

# Array associativo para rastrear AKS já processados
declare -A processedAks

# Verifica se o AKS já foi processado
isAksProcessed() {
  local aksName="$1"
  [[ -n "${processedAks[$aksName]+x}" ]]
}

# Marca o AKS como processado
markAksAsProcessed() {
  local aksName="$1"
  processedAks[$aksName]=1
}

# Verifica se o contexto já existe no kubeconfig
isContextInKubeconfig() {
  local aksName="$1"
  kubectl config get-contexts -o name 2>/dev/null | grep -q "^${aksName}$"
}

# Registra credenciais de um cluster AKS específico
registerAksCredentials() {
  local aksName="$1"
  local resourceGroup="$2"

  if isAksProcessed "$aksName"
  then
    echo "  ✓ AKS já processado nesta execução: $aksName"
    return 0
  fi

  if isContextInKubeconfig "$aksName"
  then
    echo "  ✓ AKS já cadastrado no kubeconfig: $aksName (Resource Group: $resourceGroup)"
    markAksAsProcessed "$aksName"
    return 0
  fi

  echo "  → Registrando AKS: $aksName (Resource Group: $resourceGroup)"
  az aks get-credentials --resource-group "$resourceGroup" --name "$aksName" --overwrite-existing
  markAksAsProcessed "$aksName"
}

# Lista e processa todos os clusters AKS de uma subscription
processAksClusters() {
  local subscriptionId="$1"
  local subscriptionName="$2"

  echo "\n===> Processando Subscription: $subscriptionName"
  echo "     ID: $subscriptionId"
  az account set --subscription "$subscriptionId"

  local aksClusters
  aksClusters=$(az aks list --query '[].{Name:name, ResourceGroup:resourceGroup}' -o tsv)

  if [ -z "$aksClusters" ]
  then
    echo "  ℹ Nenhum AKS encontrado nesta subscription."
    return 0
  fi

  while IFS=$'\t' read -r aksName resourceGroup
  do
    if [ -n "$aksName" ] && [ -n "$resourceGroup" ]
    then
      registerAksCredentials "$aksName" "$resourceGroup"
    fi
  done <<< "$aksClusters"
}

# Lista subscriptions e permite seleção com fzf
# foi necessário, a primeira versão gerar um loop de todas as subscription e aks
# demorava muito
selectSubscriptions() {
  echo "Carregando subscriptions..."

  local subscriptions
  subscriptions=$(az account list --query '[].{Name:name, Id:id}' -o tsv)

  if [ -z "$subscriptions" ]
  then
    echo "Erro: Nenhuma subscription encontrada."
    exit 1
  fi

  # Formata para exibição: "Nome | ID"
  local formatted
  formatted=$(echo "$subscriptions" | awk -F'\t' '{printf "%-50s | %s\n", $1, $2}')

  # Usa fzf para seleção múltipla
  local selected
  selected=$(echo "$formatted" | fzf --multi \
    --header="Selecione as subscriptions (TAB para múltipla seleção, ENTER para confirmar)" \
    --prompt="Subscriptions > " \
    --height=80% \
    --border \
    --preview-window=hidden)

  if [ -z "$selected" ]
  then
    echo "Nenhuma subscription selecionada. Saindo..."
    exit 0
  fi

  echo "$selected"
}

# Processa as subscriptions selecionadas
processSelectedSubscriptions() {
  local selected="$1"

  echo "\n=========================================="
  echo "Iniciando processamento das subscriptions selecionadas"
  echo "==========================================\n"

  while IFS='|' read -r name id
  do
    # Remove espaços em branco
    name=$(echo "$name" | xargs)
    id=$(echo "$id" | xargs)
    # Ignora linhas vazias ou sem ID
    if [ -z "$id" ] || [ -z "$name" ]
    then
      continue
    fi
    processAksClusters "$id" "$name"
  done <<< "$selected"

  echo "\n=========================================="
  echo "✓ Processamento concluído!"
  echo "==========================================\n"

  # Mostra resumo
  echo "Total de AKS processados: ${#processedAks[@]}"
  if [ ${#processedAks[@]} -gt 0 ]
  then
    echo "\nClusters AKS disponíveis:"
    kubectl config get-contexts -o name | sort
  fi
}

# Função principal
main() {
  # Verifica dependências
  if ! command -v fzf &> /dev/null
  then
    echo "Erro: fzf não está instalado. Instale com: sudo apt install fzf"
    exit 1
  fi

  if ! command -v az &> /dev/null
  then
    echo "Erro: Azure CLI não está instalado."
    exit 1
  fi

  if ! command -v kubectl &> /dev/null 
  then
    echo "Erro: kubectl não está instalado."
    exit 1
  fi

  # ajustando os arquivos para a transição
  getOldBackup

  # Seleciona subscriptions
  local selected
  selected=$(selectSubscriptions)

  # Processa subscriptions selecionadas
  processSelectedSubscriptions "$selected"

  # terminando o processo, geramos uma nova versão do backup
  saveNewVersion
}

getOldBackup() {
  # antes de iniciar obter a versão anterior para evitar recadastramento
  mv ~/.kube/config-azure ~/.kube/config
}

saveNewVersion() {
  # ao terminar, com novos cadastrados salva um novo backup
  cp ~/.kube/config ~/.kube/config-azure
}

# Executa a função principal
# e gera backup por segurança
main

# por segurança unset no contexto
kubectx -u




