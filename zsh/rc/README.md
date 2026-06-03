# Configuração Universal do Zsh

> **🌍 Configuração modular e inteligente para Zsh**  
> Compatível com **macOS**, **Linux** e **WSL** (Windows Subsystem for Linux)

[![Shell: Zsh](https://img.shields.io/badge/Shell-Zsh-green.svg)](https://www.zsh.org/)
[![asdf: v0.18.0](https://img.shields.io/badge/asdf-v0.18.0-blue.svg)](https://asdf-vm.com/)

## 🎯 Características

- ✅ **Detecção automática do sistema operacional** (macOS, Linux, WSL)
- ✅ **Suporte inteligente ao asdf v0.18.0** - detecta instalação via Git, Homebrew ou gerenciador de pacotes
- ✅ **PATH otimizado** para cada plataforma (Intel/ARM, Homebrew, Linuxbrew)
- ✅ **Aliases inteligentes** - apenas criados se os comandos existirem
- ✅ **Completions otimizados** - cache e performance para CLIs lentas (Azure, kubectl, terraform)
- ✅ **Modular e fácil de personalizar**
- ✅ **Instalador automático** com backup integrado

## 🚀 Instalação Rápida

```bash
# Navegue até o diretório do repositório
cd /caminho/para/este/repositorio

# Execute o instalador
./install.sh
```

**O instalador faz automaticamente:**
- ✅ Backup do seu `.zshrc` atual com timestamp
- ✅ Verifica/instala Oh-My-Zsh (se necessário)
- ✅ Instala plugins necessários do Oh-My-Zsh
- ✅ Copia todos os arquivos de configuração
- ✅ Cria diretórios necessários
- ✅ Verifica a instalação
- ✅ Mostra ferramentas opcionais disponíveis

<details>
<summary>📋 Instalação Manual (clique para expandir)</summary>

```bash
# 1. Backup
cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)

# 2. Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# 3. Plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

# 4. Copiar configuração
cp zshrc-universal ~/.zshrc
mkdir -p ~/.config/zsh ~/.zsh/cache
cp -r zsh/* ~/.config/zsh/

# 5. Aplicar
source ~/.zshrc
```

</details>

## 📁 Estrutura do Projeto

```
.
├── install.sh                  # 🎯 Script de instalação automatizada
├── zshrc-universal            # Arquivo principal do .zshrc
├── zsh/                       # Módulos de configuração
│   ├── 00-detect-env.zsh     # Detecção de OS e ambiente
│   ├── 01-path.zsh           # Configuração de PATH
│   ├── 02-asdf.zsh           # asdf v0.18.0 (Go version)
│   ├── 03-common.zsh         # Configurações comuns
│   ├── 04-aliases.zsh        # Aliases e funções úteis
│   └── 05-completions.zsh    # Completions otimizados
└── README.md                  # Este arquivo
```

## �� Módulos

### 00-detect-env.zsh - Detecção de Ambiente
Identifica automaticamente SO, distribuição, arquitetura e gerenciadores de pacotes.

**Variáveis:** `$OS_TYPE`, `$IS_MAC`, `$IS_LINUX`, `$IS_WSL`, `$HAS_BREW`, `$HAS_APT`, `$ARCH`

### 01-path.zsh - PATH Inteligente
- Adiciona paths apenas se existirem
- Homebrew (Intel: `/usr/local`, ARM: `/opt/homebrew`)
- Linuxbrew (`/home/linuxbrew/.linuxbrew`)
- WSL (X11, display)
- Go, Rust, Python, Krew

### 02-asdf.zsh - asdf Version Manager
Detecta instalação via Homebrew, Git ou package manager.

**Função:** `install_asdf` - mostra instruções para seu sistema

### 03-common.zsh - Configurações Comuns
- Histórico: 2M comandos, sem duplicatas
- Git: otimizado para repos grandes
- FZF: busca visual no histórico (Ctrl+R)
- Azure CLI: cache otimizado

### 04-aliases.zsh - Aliases Inteligentes
Aliases criados apenas se o comando existir:

**Geral:** `ls→exa/eza`, `cat→bat`, `top→htop`, `find→fd`  
**Git:** `g`, `gs`, `ga`, `gc`, `gp`, `gl`, `glog`  
**Docker:** `d`, `dc`, `dps`, `di`, `dex`, `dlog`  
**K8s:** `k`, `kgp`, `kgs`, `kl`, `kex`  
**Terraform:** `tf`, `tfi`, `tfp`, `tfa`

**Funções:** `mkcd`, `extract`, `myip`, `serve`

### 05-completions.zsh - Completions Otimizados
- Cache habilitado
- Fuzzy matching
- Otimizações: Azure CLI, kubectl, terraform
- Async loading para performance

## 🎨 Personalização

Crie `~/.zshrc.local` para configurações pessoais (não será sobrescrito):

```bash
# ~/.zshrc.local
alias myproject="cd ~/projetos/meu-projeto"
export MY_VAR="value"
```

Ou edite módulos em `~/.config/zsh/`

## 📋 Pré-requisitos e Ferramentas

### Obrigatório
- Zsh
- Oh-My-Zsh (instalado pelo script)

### Recomendado
- [fzf](https://github.com/junegunn/fzf) - busca fuzzy
- [asdf v0.18.0](https://asdf-vm.com/) - version manager
- [eza](https://github.com/eza-community/eza) - melhor `ls`
- [bat](https://github.com/sharkdp/bat) - melhor `cat`
- [fd](https://github.com/sharkdp/fd) - melhor `find`
- [ripgrep](https://github.com/BurntSushi/ripgrep) - melhor `grep`

<details>
<summary>📦 Instalação de ferramentas opcionais</summary>

```bash
# Ubuntu/Debian
sudo apt install fzf bat fd-find ripgrep eza

# Fedora
sudo dnf install fzf bat fd-find ripgrep eza

# macOS
brew install fzf bat eza fd ripgrep

# asdf v0.18.0
brew install asdf  # Homebrew
# ou Git (latest):
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.18.0
```

</details>

## 🐛 Troubleshooting

### Ver ambiente detectado
```bash
# Descomente print_env_info em ~/.config/zsh/00-detect-env.zsh
source ~/.zshrc
```

### Instruções asdf
```bash
install_asdf
```

### Limpar cache
```bash
rm -rf ~/.zsh/cache/* ~/.zcompdump*
source ~/.zshrc
```

### Restaurar backup
```bash
ls -lt ~/.zshrc.backup.*
cp ~/.zshrc.backup.YYYYMMDD_HHMMSS ~/.zshrc
```

### WSL - Display/X11
Edite `~/.config/zsh/01-path.zsh`:
```bash
export DISPLAY=:0              # WSLg (Win 11)
export DISPLAY=$HOST_IP:0.0    # VcXsrv/X410
```

## 📚 Compatibilidade

**Sistemas:** macOS (Intel/ARM), Linux (Ubuntu, Debian, Fedora, Arch), WSL 1/2/WSLg  
**Arquiteturas:** x86_64, ARM64 (Apple Silicon M1/M2/M3)

## 🤝 Contribuindo

Contribuições são bem-vindas! Abra issues ou PRs para:
- Reportar bugs
- Sugerir melhorias
- Adicionar suporte a novos sistemas

## 📝 Licença

Código aberto - livre para uso e modificação.

---

**Desenvolvido com ❤️ para a comunidade Zsh**
