# Markdown to PDF Converter (`md-2-pdf.sh`)

Este script converte arquivos Markdown (`.md`) para PDF de forma simples e rápida, utilizando o **Pandoc** e o motor de PDF **XeLaTeX**. Ele foi projetado para funcionar perfeitamente em sistemas **Linux** e **macOS**, validando automaticamente as dependências antes de iniciar a conversão.

---

## 🚀 Funcionalidades

- **Detecção Inteligente de OS**: Identifica se você está no macOS ou em diferentes distribuições Linux (Ubuntu/Debian, Arch Linux, Fedora/RHEL).
- **Verificação de Dependências**: Se o `pandoc` ou o `xelatex` não estiverem instalados, o script exibe comandos de instalação específicos para o seu sistema operacional.
- **Validação de Fontes**: Verifica se a fonte padrão `DejaVu Sans` está presente no sistema e, se não estiver, exibe instruções amigáveis sobre como obtê-la.
- **Tratamento Seguro de Nomes**: Extrai corretamente o nome do arquivo resultante mesmo se houver múltiplos pontos no nome do arquivo original (ex: `relatorio.v1.final.md` se tornará `relatorio.v1.final.pdf`).

---

## 🛠️ Requisitos Básicos

O script utiliza as seguintes ferramentas:
1. **Pandoc**: Conversor de documentos universal.
2. **XeLaTeX**: Motor PDF (integrante do TeX Live / MacTeX).
3. **DejaVu Sans**: A fonte principal configurada para renderizar o PDF.

---

## 💻 Como Usar

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

## 📥 Instalação das Dependências

Se você rodar o script e ele apontar dependências ausentes, use as dicas abaixo para instalá-las:

### No macOS (usando Homebrew)
```bash
# Instalar o Pandoc
brew install pandoc

# Instalar o XeLaTeX (MacTeX sem GUI/Interface Gráfica)
brew install --cask mactex-no-gui

# Instalar a fonte DejaVu (opcional, mas recomendada)
brew install --cask font-dejavu
```

### No Ubuntu / Debian / Mint
```bash
# Instalar Pandoc e XeLaTeX
sudo apt-get update
sudo apt-get install -y pandoc texlive-xetex texlive-fonts-recommended

# Instalar a fonte DejaVu
sudo apt-get install -y fonts-dejavu
```

### No Arch Linux
```bash
# Instalar Pandoc e XeLaTeX
sudo pacman -S --needed pandoc-cli texlive-bin texlive-fontsrecommended

# Instalar a fonte DejaVu
sudo pacman -S ttf-dejavu
```

### No Fedora / RHEL / CentOS
```bash
# Instalar Pandoc e XeLaTeX
sudo dnf install -y pandoc texlive-xetex texlive-collection-fontsrecommended

# Instalar a fonte DejaVu
sudo dnf install -y dejavu-sans-fonts
```
