#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<EOF
Uso:
  $(basename "$0") <owner> --all
  $(basename "$0") <owner> <repo>
  $(basename "$0") <owner>/<repo>

Argumentos:
  <owner>      Usuário ou organização proprietária dos repositórios
  <repo>       Nome do repositório pertencente a <owner>
  --all        Configura todos os repositórios não arquivados de <owner>
EOF
}

if [[ "$#" -eq 1 && "$1" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -eq 1 && "$1" == */* ]]; then
  repo="$1"
  owner="${repo%%/*}"
  target="${repo#*/}"
  if [[ -z "$owner" || -z "$target" || "$target" == */* ]]; then
    echo "Erro: use owner/repo com exatamente um separador '/'." >&2
    usage >&2
    exit 1
  fi
elif [[ "$#" -eq 2 ]]; then
  owner="$1"
  target="$2"
  if [[ "$target" == */* ]]; then
    target_owner="${target%%/*}"
    if [[ "$target_owner" != "$owner" || "${target#*/}" == */* || -z "${target#*/}" ]]; then
      echo "Erro: o repositório informado deve pertencer a '$owner'." >&2
      exit 1
    fi
    repo="$target"
    target="${target#*/}"
  fi
else
  usage
  exit 1
fi

if [[ ! "$owner" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
  echo "Erro: nome de usuário/organização inválido: '$owner'." >&2
  exit 1
fi

if [[ "$target" != "--all" && ! "$target" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "Erro: nome de repositório inválido: '$target'." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Erro: gh não encontrado no PATH." >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Erro: gh não está autenticado. Execute gh auth login." >&2
  exit 3
fi

if [[ "$target" == "--all" ]]; then
  if ! repo_list=$(gh repo list "$owner" --limit 1000 --json nameWithOwner,isArchived \
    --jq '.[] | select(.isArchived == false) | .nameWithOwner'); then
    echo "Erro: não foi possível listar os repositórios de '$owner'." >&2
    exit 4
  fi
  mapfile -t repos <<<"$repo_list"
else
  repo="${repo:-$owner/$target}"
  repos=("$repo")
fi

if [[ "${#repos[@]}" -eq 0 || -z "${repos[0]}" ]]; then
  echo "Nenhum repositório não arquivado encontrado."
  exit 0
fi

failed_steps=0
processed=0

for repo in "${repos[@]}"; do
  [[ -n "$repo" ]] || continue
  processed=$((processed + 1))
  printf '\n==> %s\n' "$repo"

  if ! default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>&1); then
    printf 'FALHA: não foi possível obter a branch padrão: %s\n' "$default_branch" >&2
    failed_steps=$((failed_steps + 1))
    continue
  fi

  if output=$(gh api -X PUT "repos/$repo/branches/$default_branch/protection" \
    --input - 2>&1 <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
  ); then
    printf 'OK: %s exige PR para merge; bypass de administradores, force-push e exclusão da branch desativados.\n' "$default_branch"
  else
    printf 'FALHA: proteção da branch %s não aplicada: %s\n' "$default_branch" "$output" >&2
    failed_steps=$((failed_steps + 1))
  fi

  if output=$(gh api -X PATCH "repos/$repo" --input - 2>&1 <<'JSON'
{
  "delete_branch_on_merge": true
}
JSON
  ); then
    echo "OK: exclusão automática da branch após merge ativada."
  else
    printf 'FALHA: não foi possível ativar a exclusão da branch após merge: %s\n' "$output" >&2
    failed_steps=$((failed_steps + 1))
  fi

  for feature in vulnerability-alerts automated-security-fixes private-vulnerability-reporting; do
    case "$feature" in
      vulnerability-alerts) description="alertas de vulnerabilidades" ;;
      automated-security-fixes) description="atualizações de segurança do Dependabot" ;;
      private-vulnerability-reporting) description="relatórios privados de vulnerabilidades" ;;
    esac

    if output=$(gh api -X PUT "repos/$repo/$feature" 2>&1); then
      printf 'OK: %s ativados.\n' "$description"
    else
      printf 'FALHA: não foi possível ativar %s: %s\n' "$description" "$output" >&2
      failed_steps=$((failed_steps + 1))
    fi
  done

  if output=$(gh api -X PATCH "repos/$repo" --input - 2>&1 <<'JSON'
{
  "security_and_analysis": {
    "secret_scanning": {
      "status": "enabled"
    },
    "secret_scanning_push_protection": {
      "status": "enabled"
    }
  }
}
JSON
  ); then
    echo "OK: secret scanning e proteção contra push de segredos ativados."
  else
    printf 'FALHA: não foi possível ativar secret scanning/proteção contra push: %s\n' "$output" >&2
    failed_steps=$((failed_steps + 1))
  fi
done

printf '\nConcluído: %d repositório(s) processado(s), %d operação(ões) com falha.\n' \
  "$processed" "$failed_steps"
if [[ "$failed_steps" -gt 0 ]]; then
  echo "Verifique as falhas acima; alguns recursos podem exigir outro plano/permissões do GitHub." >&2
  exit 5
fi
