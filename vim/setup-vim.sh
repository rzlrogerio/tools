#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE="$SCRIPT_DIR/.vimrc"
YAML_SYNTAX_SOURCE="$SCRIPT_DIR/yaml.vim"
VIM_DIR="${HOME}/.vim"
SPELL_DIR="$VIM_DIR/spell"
YCM_PYTHON="/usr/bin/python3"
YCM_DIR="$VIM_DIR/bundle/YouCompleteMe"

usage() {
  cat <<'EOF'
Uso:
  ./setup-vim.sh          Configura Vim, instala os plugins e o dicionário pt-BR.
  ./setup-vim.sh --check  Verifica a configuração sem alterá-la.
EOF
}

die() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

MODE="${1:-install}"
case "$MODE" in
  install|--check) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[[ -r /etc/os-release ]] || die "não foi possível identificar a distribuição Linux."
# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != debian && "${ID:-}" != ubuntu && " ${ID_LIKE:-} " != *" debian "* ]]; then
  die "este script oferece suporte a Debian e Ubuntu (ou derivados Debian)."
fi

[[ -f "$CONFIG_SOURCE" ]] || die "arquivo de configuração não encontrado: $CONFIG_SOURCE"
[[ -f "$YAML_SYNTAX_SOURCE" ]] || die "arquivo de sintaxe YAML não encontrado: $YAML_SYNTAX_SOURCE"

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

install_packages() {
  local packages=("$@")
  local missing=()
  local package

  for package in "${packages[@]}"; do
    if ! package_installed "$package"; then
      missing+=("$package")
    fi
  done

  if ((${#missing[@]} == 0)); then
    return
  fi

  local -a privilege=()
  if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || die "instale os pacotes como root ou instale sudo."
    privilege=(sudo)
  fi

  printf 'Instalando pacotes necessários: %s\n' "${missing[*]}"
  "${privilege[@]}" apt-get update
  "${privilege[@]}" apt-get install -y "${missing[@]}"
}

vim_has_spell() {
  command -v vim >/dev/null 2>&1 && vim --version 2>/dev/null | grep -q '+spell'
}

spell_dictionary_exists() {
  [[ -s "$SPELL_DIR/pt.utf-8.spl" ]]
}

ycm_python_supported() {
  [[ -x "$YCM_PYTHON" ]] &&
    "$YCM_PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)'
}

check_ycm_build() {
  local ycmd_dir="$YCM_DIR/third_party/ycmd"
  local build_python

  [[ -f "$YCM_DIR/install.py" ]] || return 0
  ycm_python_supported || die "YouCompleteMe requer CPython 3.12 ou superior em $YCM_PYTHON."

  [[ -r "$ycmd_dir/PYTHON_USED_DURING_BUILDING" ]] ||
    die "YouCompleteMe ainda não foi compilado; execute setup-vim.sh sem --check."
  build_python="$(<"$ycmd_dir/PYTHON_USED_DURING_BUILDING")"
  [[ -x "$build_python" ]] &&
    [[ "$(readlink -f "$build_python")" == "$(readlink -f "$YCM_PYTHON")" ]] ||
    die "YouCompleteMe foi compilado com outro Python; execute setup-vim.sh sem --check."

  "$YCM_PYTHON" -c \
    'import sys; sys.path.insert(0, sys.argv[1]); import ycm_core' "$ycmd_dir" ||
    die "o módulo nativo do YouCompleteMe não pode ser carregado; execute setup-vim.sh sem --check."
}

report_optional_tools() {
  local tool
  local missing=()
  for tool in flake8 yamllint shellcheck go gopls kubectl terraform terragrunt; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if [[ ! -x "$HOME/bin/camelcase_linter.sh" ]]; then
    missing+=(~/bin/camelcase_linter.sh)
  fi

  if ((${#missing[@]})); then
    printf 'Ferramentas opcionais não encontradas: %s\n' "${missing[*]}"
    printf 'Instale apenas as ferramentas das linguagens que você utiliza.\n'
  else
    printf 'Todas as ferramentas externas verificadas estão disponíveis.\n'
  fi
}

if [[ "$MODE" == --check ]]; then
  vim_has_spell || die "Vim não está instalado com suporte +spell (pacote recomendado: vim-nox)."
  command -v git >/dev/null 2>&1 || die "git não está instalado."
  [[ -f "$HOME/.vimrc" ]] || die "não foi encontrado ~/.vimrc; execute o script sem --check."
  [[ -d "$VIM_DIR/bundle/Vundle.vim" ]] || die "Vundle não está instalado."
  spell_dictionary_exists || die "dicionário pt-BR do Vim não encontrado em $SPELL_DIR."
  check_ycm_build
  printf 'Vim %s com +spell, configuração, Vundle e dicionário pt-BR encontrados.\n' \
    "$(vim --version | sed -n '1s/^VIM - Vi IMproved //p')"
  report_optional_tools
  exit 0
fi

if ! vim_has_spell; then
  install_packages vim-nox
fi
command -v git >/dev/null 2>&1 || install_packages git
vim_has_spell || die "o Vim instalado ainda não apresenta suporte +spell."
ycm_python_supported || die "YouCompleteMe requer CPython 3.12 ou superior em $YCM_PYTHON."
install_packages build-essential cmake python3-dev
"$YCM_PYTHON" -c \
  'import pathlib, sysconfig; raise SystemExit(0 if (pathlib.Path(sysconfig.get_path("include")) / "Python.h").is_file() else 1)' ||
  die "os headers de desenvolvimento do Python não foram encontrados; instale python3-dev."

if ! spell_dictionary_exists; then
  install_packages hunspell-pt-br
fi

mkdir -p "$VIM_DIR" "$VIM_DIR/bundle" "$SPELL_DIR"

if [[ ! -f "$HOME/.vimrc" ]]; then
  install -m 0644 "$CONFIG_SOURCE" "$HOME/.vimrc"
  printf 'Configuração instalada em %s/.vimrc\n' "$HOME"
elif ! cmp -s "$CONFIG_SOURCE" "$HOME/.vimrc"; then
  backup="$(mktemp "$HOME/.vimrc.backup.XXXXXX")"
  cp -p "$HOME/.vimrc" "$backup"
  install -m 0644 "$CONFIG_SOURCE" "$HOME/.vimrc"
  printf 'Configuração anterior preservada em %s\n' "$backup"
else
  printf 'O arquivo %s/.vimrc já está atualizado.\n' "$HOME"
fi

install -m 0644 "$YAML_SYNTAX_SOURCE" "$VIM_DIR/yaml.vim"

if ! spell_dictionary_exists; then
  dictionary_file="$(find /usr/share/hunspell /usr/share/myspell -type f \
    -iname 'pt_BR.dic' -print -quit 2>/dev/null || true)"
  [[ -n "$dictionary_file" ]] || die "hunspell-pt-br foi instalado, mas pt_BR.dic não foi encontrado."
  dictionary_prefix="${dictionary_file%.dic}"
  vim -Nu NONE -n -es \
    -c "execute 'mkspell! ' . fnameescape('$SPELL_DIR/pt') . ' ' . fnameescape('$dictionary_prefix')" \
    -c 'qa!'
  spell_dictionary_exists || die "não foi possível gerar $SPELL_DIR/pt.utf-8.spl."
  printf 'Dicionário pt-BR gerado em %s/pt.utf-8.spl\n' "$SPELL_DIR"
else
  printf 'Dicionário pt-BR existente reutilizado: %s/pt.utf-8.spl\n' "$SPELL_DIR"
fi

vundle_dir="$VIM_DIR/bundle/Vundle.vim"
if [[ ! -d "$vundle_dir" ]]; then
  git clone --depth=1 https://github.com/VundleVim/Vundle.vim.git "$vundle_dir"
elif ! git -C "$vundle_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "$vundle_dir existe, mas não é um repositório Git do Vundle."
fi

printf 'Instalando os plugins declarados no .vimrc...\n'
install_verbose_log="$VIM_DIR/vundle-install.verbose.log"
: > "$install_verbose_log"
if ! vim -V1"$install_verbose_log" -Nu "$HOME/.vimrc" -n -es "$HOME/.vimrc" \
  -c 'PluginInstall' \
  -c "call writefile(g:vundle#log, expand('~/.vim/vundle-install.log'))" \
  -c 'qa!'; then
  printf 'Erro ao instalar plugins; consulte os logs em %s/.\n' "$VIM_DIR" >&2
  tail -n 40 "$VIM_DIR/vundle-install.log" >&2
  tail -n 40 "$install_verbose_log" >&2
  exit 1
fi
rm -f "$install_verbose_log"

if [[ -f "$YCM_DIR/install.py" ]]; then
  printf 'Compilando YouCompleteMe com %s...\n' "$YCM_PYTHON"
  "$YCM_PYTHON" "$YCM_DIR/install.py" --verbose
  check_ycm_build
fi

printf 'Configuração concluída.\n'
report_optional_tools
printf 'Para verificar o resultado, execute: %s --check\n' "$SCRIPT_DIR/setup-vim.sh"
