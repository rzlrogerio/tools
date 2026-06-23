# Ferramentas Markdown (`markdown`)

Este diretório contém utilitários para trabalhar com arquivos Markdown (`.md`) no terminal.

- [`md-2-pdf.sh`](file:///hd-external/GDrive-local/1-git/1-meus/tools/markdown/md-2-pdf.sh) — Converte arquivos Markdown para PDF usando Pandoc e XeLaTeX.
- [`readmd`](file:///hd-external/GDrive-local/1-git/1-meus/tools/markdown/readmd) — Lê arquivos Markdown formatados diretamente no terminal usando Pandoc e Lynx.

---

## 1. Markdown to PDF Converter (`md-2-pdf.sh`)

Este script converte arquivos Markdown (`.md`) para PDF de forma simples e rápida, utilizando o **Pandoc** e o motor de PDF **XeLaTeX**. Ele foi projetado para funcionar perfeitamente em sistemas **Linux** e **macOS**, validando automaticamente as dependências antes de iniciar a conversão.

### 🚀 Funcionalidades
- **Detecção Inteligente de OS**: Identifica se você está no macOS ou em diferentes distribuições Linux (Ubuntu/Debian, Arch Linux, Fedora/RHEL).
- **Verificação de Dependências**: Se o `pandoc` ou o `xelatex` não estiverem instalados, o script exibe comandos de instalação específicos para o seu sistema operacional.
- **Validação de Fontes**: Verifica se a fonte padrão `DejaVu Sans` está presente no sistema e, se não estiver, exibe instruções amigáveis sobre como obtê-la.
- **Tratamento Seguro de Nomes**: Extrai corretamente o nome do arquivo resultante mesmo se houver múltiplos pontos no nome do arquivo original (ex: `relatorio.v1.final.md` se tornará `relatorio.v1.final.pdf`).

### 🛠️ Requisitos Básicos
O script utiliza as seguintes ferramentas:
1. **Pandoc**: Conversor de documentos universal.
2. **XeLaTeX**: Motor PDF (integrante do TeX Live / MacTeX).
3. **DejaVu Sans**: A fonte principal configurada para renderizar o PDF.

### 💻 Como Usar
1. Torne o script executável (necessário apenas na primeira vez):
   ```bash
   chmod +x md-2-pdf.sh
   ```
2. Execute o script passando o arquivo markdown como argumento:
   ```bash
   ./md-2-pdf.sh seu-arquivo.md
   ```
3. O PDF resultante será gerado no mesmo diretório com o nome `seu-arquivo.pdf`.

---

## 2. Markdown Reader in Terminal (`readmd`)

Este script renderiza arquivos Markdown (`.md`) formatados diretamente no terminal de forma interativa, utilizando o **Pandoc** para converter o markdown e o **Lynx** para exibição em modo texto.

### 🚀 Funcionalidades
- **Detecção Inteligente de OS**: Identifica se você está no macOS ou em diferentes distribuições Linux.
- **Verificação de Dependências**: Se o `pandoc` ou o `lynx` não estiverem instalados, o script exibe comandos de instalação específicos para o seu sistema operacional.
- **Leitura Interativa**: Exibe o conteúdo formatado em tela cheia com navegação simples via terminal.

### 🛠️ Requisitos Básicos
O script utiliza as seguintes ferramentas:
1. **Pandoc**: Conversor de documentos universal.
2. **Lynx**: Navegador de terminal em modo texto.

### 💻 Como Usar
1. Torne o script executável (necessário apenas na primeira vez):
   ```bash
   chmod +x readmd
   ```
2. Execute o script passando o arquivo markdown como argumento:
   ```bash
   ./readmd seu-arquivo.md
   ```

---

## ⚙️ Instalação no `~/bin` (Uso Global)

Para poder executar os scripts a partir de qualquer diretório no seu sistema sem precisar especificar o caminho completo, você pode criar links simbólicos (symlinks) deles no seu diretório `~/bin`.

### Passo a Passo:

1. Certifique-se de que o diretório `~/bin` existe:
   ```bash
   mkdir -p ~/bin
   ```

2. Certifique-se de que os scripts possuem permissão de execução:
   ```bash
   chmod +x md-2-pdf.sh readmd
   ```

3. Crie os links simbólicos (execute este comando de dentro do diretório `markdown` deste repositório):
   ```bash
   ln -sf "$(pwd)/md-2-pdf.sh" ~/bin/md-2-pdf
   ln -sf "$(pwd)/readmd" ~/bin/readmd
   ```

4. Garanta que o diretório `~/bin` esteja no seu `PATH`. Se não estiver, adicione a linha abaixo ao arquivo de configuração do seu shell (ex: `~/.bashrc`, `~/.zshrc` ou `~/.profile`):
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```
   Em seguida, recarregue as configurações do seu terminal:
   ```bash
   source ~/.bashrc  # ou o correspondente ao seu shell (ex: source ~/.zshrc)
   ```

Após a configuração, você poderá executar os utilitários de qualquer diretório utilizando apenas:
```bash
readmd seu-arquivo.md
md-2-pdf seu-arquivo.md
```

---

## 📥 Instalação das Dependências (Ambos os Scripts)

Se você rodar os scripts e eles apontarem dependências ausentes, use as dicas abaixo para instalá-las de acordo com seu sistema operacional:

### No macOS (usando Homebrew)
```bash
# Instalar o Pandoc (necessário para ambos)
brew install pandoc

# Instalar o Lynx (necessário para o readmd)
brew install lynx

# Instalar o XeLaTeX (MacTeX sem GUI, necessário para md-2-pdf.sh)
brew install --cask mactex-no-gui

# Instalar a fonte DejaVu (necessária para md-2-pdf.sh)
brew install --cask font-dejavu
```

### No Ubuntu / Debian / Mint
```bash
# Atualizar repositórios
sudo apt-get update

# Instalar dependências para readmd
sudo apt-get install -y pandoc lynx

# Instalar dependências adicionais para md-2-pdf.sh (XeLaTeX e fonte DejaVu)
sudo apt-get install -y texlive-xetex texlive-fonts-recommended fonts-dejavu
```

### No Arch Linux
```bash
# Instalar dependências para readmd
sudo pacman -S --needed pandoc-cli lynx

# Instalar dependências adicionais para md-2-pdf.sh (XeLaTeX e fonte DejaVu)
sudo pacman -S --needed texlive-bin texlive-fontsrecommended ttf-dejavu
```

### No Fedora / RHEL / CentOS
```bash
# Instalar dependências para readmd
sudo dnf install -y pandoc lynx

# Instalar dependências adicionais para md-2-pdf.sh (XeLaTeX e fonte DejaVu)
sudo dnf install -y texlive-xetex texlive-collection-fontsrecommended dejavu-sans-fonts
```
