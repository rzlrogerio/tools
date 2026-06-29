# Utilitários para WSL (`wsl`)

Este diretório contém uma coleção de scripts, configurações e guias para otimizar e facilitar a experiência de uso do **WSL (Windows Subsystem for Linux)**.

## 📁 Estrutura de Diretórios

Cada subdiretório possui uma finalidade específica com sua própria documentação:

- [**`backup/`**](file:///hd-external/GDrive-local/1-git/1-meus/tools/wsl/backup/README.md)
  - Solução automatizada para realizar backup periódico (via `rsync` e `cron`) de pastas e configurações do WSL diretamente para o seu OneDrive no Windows.
- [**`browser/`**](file:///hd-external/GDrive-local/1-git/1-meus/tools/wsl/browser/README.md)
  - Scripts utilitários (como `chrome-wrapper.sh`) para integrar navegadores do Windows com o WSL, otimizando fluxos de login e redirecionamentos.
- [**`dns/`****[NOVO]**](file:///hd-external/GDrive-local/1-git/1-meus/tools/wsl/dns/README.md)
  - Script `fix-dns.sh` para resolver falhas de conexão de rede e DNS no WSL, muito comum ao utilizar VPNs corporativas.
- [**`ssh/`****[NOVO]**](file:///hd-external/GDrive-local/1-git/1-meus/tools/wsl/ssh/README.md)
  - Script `sync-ssh.sh` para importar chaves SSH do Windows para o WSL de forma segura e configurando automaticamente as permissões corretas exigidas pelo Linux.
- [**`wslconf-optimized/`**](file:///hd-external/GDrive-local/1-git/1-meus/tools/wsl/wslconf-optimized/README.md)
  - Configuração global otimizada (`wslconfig`) para limitar o uso de CPU e memória RAM do WSL2, além de ativar recursos experimentais como a liberação automática de memória.

---

## 🚀 Como Usar

Navegue até o diretório da ferramenta desejada e siga as instruções contidas no `README.md` correspondente para realizar a instalação e configuração.
