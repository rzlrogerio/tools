#!/usr/bin/env bash
set -Eeuo pipefail

readonly DATA_ROOT="/general-use/1-lab/k8s/k3s"
readonly STORAGE_ROOT="${DATA_ROOT}/storage"
readonly DATA_MOUNT="/general-use"
readonly VAULT_NAMESPACE="vault"
readonly GITLAB_NAMESPACE="gitlab"
readonly GITLAB_RELEASE="gitlab"
readonly GITLAB_CHART_VERSION="8.11.0"
readonly RUNNER_CHART_VERSION="0.74.1"
readonly AGENT_CHART_VERSION="2.14.0"
readonly GITLAB_WEB_URL="http://gitlab-webservice-default.gitlab.svc.cluster.local:8080"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

on_error() {
  local status=$?
  printf '[ERROR] Falha na linha %s (codigo %s). Consulte o estado do cluster com kubectl.\n' "$1" "$status" >&2
  exit "$status"
}
trap 'on_error "$LINENO"' ERR

mode="${1:-}"
if [[ "$#" -ne 1 || ( "$mode" != "--recreate-gitlab" && "$mode" != "--resume-gitlab" ) ]]; then
  fail "Uso: $0 --recreate-gitlab | --resume-gitlab"
fi

for command_name in kubectl helm jq curl openssl findmnt ip hostname; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Comando obrigatorio ausente: $command_name"
done

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
systemctl is-active --quiet k3s || fail "O servico k3s nao esta ativo."
findmnt --mountpoint "$DATA_MOUNT" >/dev/null ||
  fail "O volume $DATA_MOUNT nao esta montado."
unit_exec="$(systemctl show k3s -p ExecStart --value)"
[[ "$unit_exec" == *"--data-dir $DATA_ROOT"* ]] ||
  fail "O servico k3s nao esta configurado com --data-dir $DATA_ROOT."

node_path_map="$(kubectl get configmap local-path-config -n kube-system -o json | jq -r '.data["config.json"]')"
jq -e --arg path "$STORAGE_ROOT" '.nodePathMap | any(.paths | index($path))' <<<"$node_path_map" >/dev/null ||
  fail "local-path nao esta configurado para usar $STORAGE_ROOT."

kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl get namespace "$VAULT_NAMESPACE" >/dev/null ||
  fail "O namespace Vault nao existe; o script preserva a instancia existente e nao a reinstala."
kubectl get pod vault-0 -n "$VAULT_NAMESPACE" >/dev/null ||
  fail "O pod vault-0 nao existe; nenhuma alteracao no GitLab foi iniciada."

readonly WORK_DIR="$(mktemp -d)"
chmod 0700 "$WORK_DIR"
cleanup() {
  find "$WORK_DIR" -type f -delete
  rmdir "$WORK_DIR"
}
trap cleanup EXIT

vault_status=""
for _ in {1..40}; do
  vault_status="$(kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault status -format=json 2>/dev/null || true)"
  if jq -e '.initialized != null' >/dev/null 2>&1 <<<"$vault_status"; then
    break
  fi
  sleep 3
done
jq -e '.initialized != null' >/dev/null 2>&1 <<<"$vault_status" ||
  fail "Vault nao respondeu ao comando de status."

if [[ "$(jq -r '.initialized' <<<"$vault_status")" != "true" ]]; then
  init_json="$(kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json)"
  unseal_key="$(jq -er '.unseal_keys_b64[0]' <<<"$init_json")"
  vault_root_token="$(jq -er '.root_token' <<<"$init_json")"
  kubectl create secret generic vault-credentials \
    --namespace "$VAULT_NAMESPACE" \
    --from-literal=unseal-key="$unseal_key" \
    --from-literal=root-token="$vault_root_token" \
    --dry-run=client -o yaml | kubectl apply -f -
  vault_status="$(kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault status -format=json)"
else
  kubectl get secret vault-credentials -n "$VAULT_NAMESPACE" >/dev/null ||
    fail "Vault esta inicializado, mas o secret vault-credentials nao existe. O GitLab nao foi alterado."
  unseal_key="$(kubectl get secret vault-credentials -n "$VAULT_NAMESPACE" -o jsonpath='{.data.unseal-key}' | base64 -d)"
  vault_root_token="$(kubectl get secret vault-credentials -n "$VAULT_NAMESPACE" -o jsonpath='{.data.root-token}' | base64 -d)"
  [[ -n "$unseal_key" && -n "$vault_root_token" ]] ||
    fail "O secret vault-credentials nao contem as credenciais esperadas."
fi

if [[ "$(jq -r '.sealed' <<<"$vault_status")" == "true" ]]; then
  log "Deslacrando o Vault existente."
  kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- vault operator unseal "$unseal_key" >/dev/null
fi
unset unseal_key

kubectl wait --for=condition=Ready pod/vault-0 -n "$VAULT_NAMESPACE" --timeout=180s

vault_exec() {
  kubectl exec -n "$VAULT_NAMESPACE" vault-0 -- env \
    VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$vault_root_token" "$@"
}

if ! vault_exec vault auth list -format=json | jq -e 'has("kubernetes/")' >/dev/null; then
  vault_exec vault auth enable kubernetes
fi
vault_exec vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc"
if ! vault_exec vault secrets list -format=json | jq -e 'has("secret/")' >/dev/null; then
  vault_exec vault secrets enable -path=secret kv-v2
fi

db_password="$(openssl rand -hex 32)"
vault_exec vault kv put secret/devops/ci-cd \
  db_user="sre_admin" db_password="$db_password" env="local"
unset db_password

if ! vault_exec vault policy read gitlab-runner-policy >/dev/null 2>&1; then
  printf 'path "secret/data/*" { capabilities = ["read"] }\n' |
    kubectl exec -i -n "$VAULT_NAMESPACE" vault-0 -- env \
      VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$vault_root_token" \
      vault policy write gitlab-runner-policy -
fi
vault_exec vault write auth/kubernetes/role/gitlab-runner \
  bound_service_account_names=default,gitlab-runner \
  bound_service_account_namespaces=gitlab,default \
  policies=gitlab-runner-policy ttl=24h
unset vault_root_token
log "Vault existente esta inicializado, deslacrado e configurado."

host_ip="${DEVOPS_HOST_IP:-$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')}"
if [[ -z "$host_ip" ]]; then
  host_ip="$(hostname -I | awk '{print $1}')"
fi
[[ -n "$host_ip" ]] || fail "Nao foi possivel determinar o IP do host."
domain="${DEVOPS_DOMAIN:-${host_ip}.nip.io}"

helm repo add gitlab https://charts.gitlab.io/ --force-update
helm repo update gitlab

if [[ "$mode" == "--recreate-gitlab" ]]; then
  log "Removendo os recursos GitLab antigos (Registry, Runner e Agent incluidos)."
  if helm status "$GITLAB_RELEASE" -n "$GITLAB_NAMESPACE" >/dev/null 2>&1; then
    helm uninstall "$GITLAB_RELEASE" -n "$GITLAB_NAMESPACE"
  fi
  kubectl delete namespace "$GITLAB_NAMESPACE" --ignore-not-found --wait=true --timeout=180s

  for _ in {1..60}; do
    stale_pvs="$(kubectl get pv -o json | jq -r '
      .items[]
      | select(.spec.local.path? | strings | startswith("/home/rancher/k3s/data/"))
      | .metadata.name
    ')"
    [[ -z "$stale_pvs" ]] && break
    sleep 3
  done
  [[ -z "${stale_pvs:-}" ]] ||
    fail "Ainda existem PVs GitLab apontando para /home/rancher/k3s/data: $stale_pvs"

  kubectl create namespace "$GITLAB_NAMESPACE"
  gitlab_root_password="$(openssl rand -base64 36 | tr -d '\n')"
  kubectl create secret generic gitlab-gitlab-initial-root-password \
    --namespace "$GITLAB_NAMESPACE" \
    --from-literal=password="$gitlab_root_password"
else
  kubectl get namespace "$GITLAB_NAMESPACE" >/dev/null ||
    fail "O namespace GitLab nao existe; use --recreate-gitlab para uma instalacao limpa."
  helm status "$GITLAB_RELEASE" -n "$GITLAB_NAMESPACE" >/dev/null ||
    fail "O release GitLab nao existe; use --recreate-gitlab."
  kubectl get secret gitlab-gitlab-initial-root-password -n "$GITLAB_NAMESPACE" >/dev/null ||
    fail "O secret da senha inicial GitLab esta ausente."
fi

cat >"$WORK_DIR/gitlab-values.yaml" <<EOF
global:
  edition: ce
  hosts:
    domain: "${domain}"
    hostSuffix: ""
    https: false
    registry:
      name: "registry.${domain}"
  ingress:
    apiVersion: networking.k8s.io/v1
    configureCertmanager: false
    enabled: true
    provider: traefik
    class: traefik
    tls:
      enabled: false
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: web
  kas:
    enabled: true
  hpa:
    apiVersion: autoscaling/v2
  pdb:
    apiVersion: policy/v1
  initialRootPassword:
    secret: gitlab-gitlab-initial-root-password
    key: password
  minio:
    enabled: true

nginx-ingress:
  enabled: false
certmanager:
  install: false
certmanager-issuer:
  email: admin@local.domain
prometheus:
  install: false
gitlab-runner:
  install: false
registry:
  enabled: true
  hpa:
    minReplicas: 1
    maxReplicas: 1

gitlab:
  webservice:
    minReplicas: 1
    maxReplicas: 1
    workerProcesses: 2
    resources:
      requests:
        cpu: 100m
        memory: 1Gi
      limits:
        memory: 2.5Gi
  sidekiq:
    minReplicas: 1
    maxReplicas: 1
    concurrency: 5
    resources:
      requests:
        cpu: 50m
        memory: 400Mi
  gitaly:
    resources:
      requests:
        cpu: 50m
        memory: 200Mi
  gitlab-shell:
    minReplicas: 1
    maxReplicas: 1
    traefik:
      apiVersion: traefik.io/v1alpha1
  kas:
    minReplicas: 1
    maxReplicas: 1

postgresql:
  install: true
  image:
    registry: docker.io
    repository: bitnamilegacy/postgresql
    tag: "15.4.0-debian-11-r45"
  primary:
    resources:
      requests:
        cpu: 50m
        memory: 256Mi
  metrics:
    image:
      registry: docker.io
      repository: bitnamilegacy/postgres-exporter
      tag: "0.14.0-debian-11-r2"

redis:
  install: true
  image:
    registry: docker.io
    repository: bitnamilegacy/redis
    tag: "7.2.4-debian-12-r9"
  master:
    resources:
      requests:
        cpu: 30m
        memory: 128Mi
  metrics:
    image:
      registry: docker.io
      repository: bitnamilegacy/redis-exporter
      tag: "1.58.0-debian-12-r4"

minio:
  image: docker.io/bitnamilegacy/minio
  imageTag: 2023.9.7-debian-11-r5
  minioMc:
    image: docker.io/bitnamilegacy/minio-client
    tag: 2023.9.7-debian-11-r5
EOF
chmod 0600 "$WORK_DIR/gitlab-values.yaml"

log "Instalando GitLab CE com Registry habilitado; volumes serao provisionados em $STORAGE_ROOT."
helm upgrade --install "$GITLAB_RELEASE" gitlab/gitlab \
  --version "$GITLAB_CHART_VERSION" \
  --namespace "$GITLAB_NAMESPACE" \
  -f "$WORK_DIR/gitlab-values.yaml" \
  --force-conflicts \
  --skip-schema-validation \
  --timeout 1200s

kubectl patch deployment gitlab-minio -n "$GITLAB_NAMESPACE" --type=strategic -p '
spec:
  template:
    spec:
      containers:
        - name: minio
          command:
            - /opt/bitnami/minio/bin/minio
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: gitlab-minio-secret
                  key: accesskey
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: gitlab-minio-secret
                  key: secretkey
          securityContext:
            runAsUser: 1001
'
kubectl rollout status deployment/gitlab-minio -n "$GITLAB_NAMESPACE" --timeout=300s

initializer="$(kubectl get configmap gitlab-minio-config-cm -n "$GITLAB_NAMESPACE" -o json |
  jq -er '.data.initialize')"
initializer="${initializer//\/usr\/bin\/mc/\/opt\/bitnami\/minio-client\/bin\/mc}"
kubectl get configmap gitlab-minio-config-cm -n "$GITLAB_NAMESPACE" -o json |
  jq --arg script "$initializer" '.data.initialize = $script' |
  kubectl replace -f -

bucket_job="$(
  kubectl get jobs -n "$GITLAB_NAMESPACE" -l app=minio -o json |
    jq -er '[.items[] | select(.metadata.name | startswith("gitlab-minio-create-buckets-"))]
      | sort_by(.metadata.creationTimestamp) | last | .metadata.name'
)"
kubectl get job "$bucket_job" -n "$GITLAB_NAMESPACE" -o json |
  jq '
    del(.metadata.annotations, .metadata.creationTimestamp, .metadata.generation,
        .metadata.managedFields, .metadata.resourceVersion, .metadata.uid, .status)
    | .metadata.name = "gitlab-minio-create-buckets-bootstrap"
    | .metadata.labels |= with_entries(select(
        .key != "batch.kubernetes.io/controller-uid" and
        .key != "controller-uid" and
        .key != "batch.kubernetes.io/job-name" and
        .key != "job-name"
      ))
    | .spec |= del(.selector, .manualSelector)
    | .spec.template.metadata.labels |= with_entries(select(
        .key != "batch.kubernetes.io/controller-uid" and
        .key != "controller-uid" and
        .key != "batch.kubernetes.io/job-name" and
        .key != "job-name"
      ))
  ' >"$WORK_DIR/minio-buckets-job.json"
kubectl delete job gitlab-minio-create-buckets-bootstrap -n "$GITLAB_NAMESPACE" \
  --ignore-not-found --wait=true
kubectl delete job "$bucket_job" -n "$GITLAB_NAMESPACE" --wait=true
kubectl create -f "$WORK_DIR/minio-buckets-job.json"
kubectl wait --for=condition=complete job/gitlab-minio-create-buckets-bootstrap \
  -n "$GITLAB_NAMESPACE" --timeout=300s
kubectl rollout status deployment/gitlab-webservice-default -n "$GITLAB_NAMESPACE" --timeout=1200s
kubectl rollout status deployment/gitlab-kas -n "$GITLAB_NAMESPACE" --timeout=300s
kubectl rollout status deployment/gitlab-registry -n "$GITLAB_NAMESPACE" --timeout=300s
unset gitlab_root_password 2>/dev/null || true

log "Criando credenciais de bootstrap, projeto GitOps, Runner e Agent."
gitlab_service_ip="$(kubectl get service gitlab-webservice-default \
  --namespace "$GITLAB_NAMESPACE" -o jsonpath='{.spec.clusterIP}')"
[[ -n "$gitlab_service_ip" ]] || fail "Nao foi possivel localizar o IP interno do GitLab."
gitlab_api_url="http://${gitlab_service_ip}:8080"

if kubectl get secret gitlab-bootstrap-token -n "$GITLAB_NAMESPACE" >/dev/null 2>&1; then
  bootstrap_token="$(kubectl get secret gitlab-bootstrap-token -n "$GITLAB_NAMESPACE" -o jsonpath='{.data.token}' | base64 -d)"
else
  bootstrap_token="$(
    kubectl exec -n "$GITLAB_NAMESPACE" deployment/gitlab-webservice-default -c webservice -- \
      /scripts/exec-env /srv/gitlab/bin/rails runner '
        user = User.find_by_username("root")
        token = SecureRandom.hex(32)
        pat = user.personal_access_tokens.create!(
          name: "k3s-bootstrap",
          scopes: ["api", "read_api", "read_repository", "write_repository"],
          expires_at: 1.year.from_now
        )
        pat.set_token(token)
        pat.save!
        print token
      '
  )"
  [[ -n "$bootstrap_token" ]] || fail "Nao foi possivel criar o token de bootstrap do GitLab."
  kubectl create secret generic gitlab-bootstrap-token \
    --namespace "$GITLAB_NAMESPACE" --from-literal=token="$bootstrap_token"
fi

project_json="$(curl -fsS -H "PRIVATE-TOKEN: $bootstrap_token" \
  "$gitlab_api_url/api/v4/projects/root%2Fcluster-management" 2>/dev/null)" || {
  project_json="$(curl -fsS -X POST "$gitlab_api_url/api/v4/projects" \
    -H "PRIVATE-TOKEN: $bootstrap_token" \
    -H "Content-Type: application/json" \
    -d '{"name":"cluster-management","visibility":"internal","initialize_with_readme":true}')"
}
project_id="$(jq -er '.id' <<<"$project_json")"

agent_id=""
if kubectl get secret k3s-agent-token -n "$GITLAB_NAMESPACE" >/dev/null 2>&1; then
  agent_token="$(kubectl get secret k3s-agent-token -n "$GITLAB_NAMESPACE" -o jsonpath='{.data.token}' | base64 -d)"
else
  agent_json="$(curl -fsS -H "PRIVATE-TOKEN: $bootstrap_token" \
    "$gitlab_api_url/api/v4/projects/${project_id}/cluster_agents")"
  agent_id="$(jq -r '.[] | select(.name=="k3s-agent") | .id' <<<"$agent_json" | head -n 1)"
  if [[ -z "$agent_id" ]]; then
    agent_json="$(curl -fsS -X POST "$gitlab_api_url/api/v4/projects/${project_id}/cluster_agents" \
      -H "PRIVATE-TOKEN: $bootstrap_token" \
      -H "Content-Type: application/json" -d '{"name":"k3s-agent"}')"
    agent_id="$(jq -er '.id' <<<"$agent_json")"
  fi
  agent_token="$(curl -fsS -X POST \
    "$gitlab_api_url/api/v4/projects/${project_id}/cluster_agents/${agent_id}/tokens" \
    -H "PRIVATE-TOKEN: $bootstrap_token" \
    -H "Content-Type: application/json" \
    -d '{"name":"k3s-agent-token","description":"K3s local cluster agent"}' | jq -er '.token')"
  kubectl create secret generic k3s-agent-token \
    --namespace "$GITLAB_NAMESPACE" --from-literal=token="$agent_token"
fi

if kubectl get secret gitlab-runner-token -n "$GITLAB_NAMESPACE" >/dev/null 2>&1; then
  runner_token="$(kubectl get secret gitlab-runner-token -n "$GITLAB_NAMESPACE" -o jsonpath='{.data.token}' | base64 -d)"
else
  runner_token="$(curl -fsS -X POST "$gitlab_api_url/api/v4/user/runners" \
    -H "PRIVATE-TOKEN: $bootstrap_token" \
    -H "Content-Type: application/json" \
    -d '{"runner_type":"instance_type","description":"k3s-shared-runner","tag_list":"k3s,docker","run_untagged":true}' \
    | jq -er '.token')"
  kubectl create secret generic gitlab-runner-token \
    --namespace "$GITLAB_NAMESPACE" --from-literal=token="$runner_token"
fi
unset bootstrap_token

unset agent_token

cat >"$WORK_DIR/runner-values.yaml" <<EOF
gitlabUrl: "${GITLAB_WEB_URL}"
runnerToken: "${runner_token}"
rbac:
  create: true
  clusterWideAccess: true
serviceAccount:
  create: true
runners:
  tags: "k3s,docker,kubernetes"
  privileged: true
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "${GITLAB_NAMESPACE}"
        image = "docker:24.0.5-dind"
        privileged = true
        cpu_request = "200m"
        memory_request = "256Mi"
        service_account = "gitlab-runner"
EOF
chmod 0600 "$WORK_DIR/runner-values.yaml"
helm upgrade --install gitlab-runner gitlab/gitlab-runner \
  --version "$RUNNER_CHART_VERSION" \
  --namespace "$GITLAB_NAMESPACE" -f "$WORK_DIR/runner-values.yaml"
unset runner_token
kubectl rollout status deployment/gitlab-runner -n "$GITLAB_NAMESPACE" --timeout=300s

cat >"$WORK_DIR/agent-values.yaml" <<EOF
replicas: 1
config:
  kasAddress: "grpc://gitlab-kas.${GITLAB_NAMESPACE}.svc.cluster.local:8150"
  secretName: "k3s-agent-token"
rbac:
  create: true
  useExistingRole: "cluster-admin"
EOF
chmod 0600 "$WORK_DIR/agent-values.yaml"
helm upgrade --install k3s-agent gitlab/gitlab-agent \
  --version "$AGENT_CHART_VERSION" \
  --namespace "$GITLAB_NAMESPACE" -f "$WORK_DIR/agent-values.yaml"
kubectl rollout status deployment/k3s-agent-gitlab-agent-v2 -n "$GITLAB_NAMESPACE" --timeout=300s

log "Conferindo caminhos de armazenamento dos novos PVs."
kubectl get pv -o json | jq -r '
  .items[]
  | select(.spec.claimRef.namespace == "gitlab")
  | [.metadata.name, .spec.local.path]
  | @tsv
' | tee "$WORK_DIR/gitlab-pv-paths.tsv"
if grep -vF "$STORAGE_ROOT/" "$WORK_DIR/gitlab-pv-paths.tsv" >/dev/null; then
  fail "Um ou mais PVs GitLab nao foram criados sob $STORAGE_ROOT."
fi

cat <<SUMMARY

Stack instalada:
  GitLab:    http://gitlab.${domain}
  Registry:  http://registry.${domain}
  Vault:     http://vault.${domain}

Credenciais:
  Usuario GitLab: root
  Para recuperar a senha inicial:
    kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d; echo

Tokens ficam guardados em Secrets Kubernetes; o script nao os imprime.
SUMMARY
