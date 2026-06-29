# WSL DNS Fixer

Este utilitário resolve problemas frequentes de resolução de nomes (DNS) dentro do WSL, especialmente comuns ao se conectar a VPNs corporativas ou redes com configurações de DNS restritas.

## 📋 O Problema

Por padrão, o WSL gera o arquivo `/etc/resolv.conf` automaticamente a cada inicialização, apontando para o próprio host do Windows. No entanto, ao conectar a uma VPN no Windows, ou em certas redes, a resolução de nomes de dentro do WSL pode falhar.

## 🚀 Como Funciona o Script

O script `fix-dns.sh`:
1. Desativa a geração automática do `/etc/resolv.conf` no arquivo de configuração do WSL (`/etc/wsl.conf`).
2. Remove o link simbólico padrão do `/etc/resolv.conf`.
3. Cria um novo `/etc/resolv.conf` estático contendo:
   - DNS Público do Google (`8.8.8.8`)
   - DNS Público da Cloudflare (`1.1.1.1`)
   - O IP do gateway do host Windows (para resolver nomes da rede local/VPN).

## 💻 Como Usar

1. Torne o script executável:
   ```bash
   chmod +x fix-dns.sh
   ```

2. Execute o script com privilégios de superusuário (sudo):
   ```bash
   sudo ./fix-dns.sh
   ```

3. Se necessário, reinicie o WSL no PowerShell do Windows para aplicar todas as configurações de rede:
   ```powershell
   wsl --shutdown
   ```

## 🛠️ Requisitos
- WSL2 (Ubuntu ou outras distribuições baseadas em Debian/RedHat).
- Acesso de superusuário (`sudo`).
