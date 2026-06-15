#!/bin/bash
#

# Limpa variáveis de ambiente AWS para evitar conflitos com SSO
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE

#rm -f ~/.kube/config
aws sso logout

AWS_REGIONS="sa-east-1 \
us-east-1"

PROFILE="${1:-}"
PROFILE_STATUS="/tmp/prfsts"

write_empty_kubeconfig()
{
  mkdir -p ~/.kube
  cat > ~/.kube/config << 'EOF'
apiVersion: v1
clusters: []
contexts: []
current-context: ""
kind: Config
preferences: {}
users: []
EOF
}

ensure_valid_kubeconfig()
{
  if [ ! -f ~/.kube/config ]; then
    write_empty_kubeconfig
    return 0
  fi

  if ! kubectl config view >/dev/null 2>&1; then
    invalid_backup="$HOME/.kube/config.invalid.$(date +%Y%m%d%H%M%S)"
    cp ~/.kube/config "$invalid_backup" 2>/dev/null || true
    echo "⚠ kubeconfig inválido detectado. Recriando arquivo limpo (backup: $invalid_backup)."
    write_empty_kubeconfig
  fi
}

fn_valida_profile()
{
  if [ -z "$PROFILE" ]; then
    # lista os profiles e permite seleção com fzf
    echo "Selecione o profile AWS para login:"
    PROFILE=$(cat ~/.aws/config | grep profile | sed -e 's/\[//g' -e 's/\]//g' | awk '{ print $2 }' | fzf --height=20% --prompt="Profile > " --border)
    if [ -z "$PROFILE" ]; then
      echo "Nenhum profile selecionado. Abortando."
      exit 1
    fi
  fi

  # Salva o profile após validação
  echo "$PROFILE" > "$PROFILE_STATUS"

  cat ~/.aws/config | grep profile | sed -e 's/\[//g' -e 's/\]//g' | awk '{ print $2 }' | grep -w $PROFILE > /dev/null
  if [ $? != 0 ]; then
    echo " "
    echo "profile invalido, possiveis sao $(cat ~/.aws/config | grep profile | sed -e 's/\[//g' -e 's/\]//g' | awk '{ print $2 }')"
    echo " "
  else
    fn_exec_login_get_cluster
  fi

}

fn_exec_login_get_cluster()
{
  fn_get_old_backup

  # Garante que não há variáveis de ambiente conflitantes antes do login
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  #aws sso login --no-browser --profile $PROFILE
  aws sso login --profile $PROFILE

  # Verifica se o login foi bem-sucedido
  if ! aws sts get-caller-identity --profile $PROFILE >/dev/null 2>&1; then
    echo "Erro: Login AWS SSO falhou ou credenciais inválidas"
    exit 1
  fi

  fn_sync_default_profile

  # Atualiza o cache da conta AWS para o prompt
  ~/bin/get-aws-account.sh --update >/dev/null 2>&1

  # Lista e registra todos os clusters EKS automaticamente
  fn_select_and_register_eks_clusters

  # apenas para ficar limpo - desativa o contexto atual se existir
  if command -v kubectx &> /dev/null; then
    kubectx -u 2>/dev/null || true
  fi

  fn_save_new_backup
}

# Lista e registra todos os clusters EKS disponíveis
fn_select_and_register_eks_clusters() {
  echo "Localizando clusters EKS..."

  ensure_valid_kubeconfig

  for aws_region in $(echo $AWS_REGIONS)
  do
    EKS_CLUSTER=$(aws eks list-clusters --profile $PROFILE --region $aws_region | jq -r '.clusters[]' 2>/dev/null || true)

    if [ -z "$EKS_CLUSTER" ]; then
      echo "Profile $PROFILE na regiao $aws_region sem cluster EKS"
      continue
    fi

    while read -r eks_cluster
    do
      [ -z "$eks_cluster" ] && continue

      # Sempre atualiza o kubeconfig para garantir que o contexto apareça no kubectx.
      echo "  → Registrando EKS cluster: $eks_cluster (região: $aws_region)"
      aws eks update-kubeconfig --name "$eks_cluster" --profile $PROFILE --region $aws_region >/dev/null
    done <<< "$EKS_CLUSTER"
  done
}

fn_get_old_backup() {
  # Salva o config atual como backup da Azure (antes de restaurar AWS)
  if [ -f ~/.kube/config ]; then
    cp ~/.kube/config ~/.kube/config-azure
  fi

  # Restaura o backup anterior da AWS se existir
  if [ -f ~/.kube/config-aws ]; then
    # Move o backup para ser o config atual
    # Isso garante que APENAS clusters da AWS estarão disponíveis
    mv ~/.kube/config-aws ~/.kube/config
  else
    # Se não existe backup da AWS, cria um vazio
    # Isso limpa qualquer cluster anterior
    write_empty_kubeconfig
  fi

  ensure_valid_kubeconfig
  # Remove qualquer contexto da Azure que possa ter contaminado o config da AWS
  fn_cleanup_azure_contexts
}

# Remove todos os contextos e clusters da Azure do config
fn_cleanup_azure_contexts() {
  # Encontra e remove contextos que NÃO são da AWS (usando lista negra)
  # Mantém: arn:aws, eks-, minikube
  # Remove: akspriv-, -hlg, etc
  local all_contexts
  all_contexts=$(kubectl config get-contexts -o name 2>/dev/null || true)

  if [ -n "$all_contexts" ]; then
    while read -r context; do
      [ -z "$context" ] && continue

      # Se NÃO matches AWS ou minikube, remove
      if ! echo "$context" | grep -qE "arn:aws|^eks-|^minikube"; then
        echo "  🧹 Removendo contexto: $context"
        kubectl config delete-context "$context" 2>/dev/null || true
      fi
    done <<< "$all_contexts"
  fi

  # Remove clusters da Azure
  local clusters_to_remove
  clusters_to_remove=$(kubectl config get-clusters 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v -E "arn:aws|^eks-|minikube" || true)

  if [ -n "$clusters_to_remove" ]; then
    while read -r cluster; do
      [ -z "$cluster" ] && continue
      kubectl config delete-cluster "$cluster" 2>/dev/null || true
    done <<< "$clusters_to_remove"
  fi
}

fn_save_new_backup() {
  # preservo depois de cadastrar novos eks
  cp ~/.kube/config ~/.kube/config-aws
}

fn_sync_default_profile() {
  fields="sso_start_url sso_region sso_account_id sso_role_name region output"
  for field in $fields
  do
    value=$(aws configure get $field --profile $PROFILE 2>/dev/null)
    if [ -z "$value" ] && [ "$field" = "output" ]; then
      value="json"
    fi

    if [ -n "$value" ]; then
      aws configure set $field "$value" --profile default >/dev/null 2>&1
    else
      aws configure unset $field --profile default >/dev/null 2>&1
    fi
  done

  if [ -z "$(aws configure get output --profile default 2>/dev/null)" ]; then
    aws configure set output "json" --profile default >/dev/null 2>&1
  fi

  for cred_field in aws_access_key_id aws_secret_access_key aws_session_token
  do
    aws configure set $cred_field "" --profile default >/dev/null 2>&1
  done
}

fn_valida_profile
