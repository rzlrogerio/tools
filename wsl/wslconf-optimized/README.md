# WSL Otimizado (`wslconf-optimized`)

Este diretório contém uma configuração otimizada e recomendada para o WSL2 (`.wslconfig`), com foco em desempenho, controle de consumo de memória e uso de recursos experimentais.

## 📋 O que é o `.wslconfig`?

O arquivo `.wslconfig` é usado para definir configurações globais para todas as distribuições instaladas que rodam no WSL2. Ao contrário do `/etc/wsl.conf` (que é específico de cada distribuição), o `.wslconfig` deve ser colocado no diretório de perfil do seu usuário no Windows.

## 🚀 Recursos Otimizados Incluídos

- **Controle de Memória (`memory=6GB`)**: Limita a memória máxima que o WSL2 pode consumir (o padrão do WSL2 pode consumir até 80% da memória da máquina, o que pode deixar o Windows lento). Ajuste este valor conforme a sua quantidade total de RAM.
- **Limite de CPU (`processors=2`)**: Define quantos cores virtuais o WSL2 pode utilizar.
- **Auto Memory Reclaim (`autoMemoryReclaim=gradual`)**: Recurso experimental que libera memória RAM de cache de volta para o Windows de forma gradual quando o WSL2 não estiver usando.
- **DNS Tunneling (`dnsTunneling=true`)**: Melhora a conectividade de rede e resolução de nomes ao passar as requisições de DNS pelo Windows, ideal para uso com VPNs.

## 💻 Como Instalar

1. Abra o PowerShell ou o Explorador de Arquivos no Windows.
2. Copie o arquivo `wslconfig` deste diretório para a pasta do seu perfil de usuário no Windows com o nome de `.wslconfig` (com um ponto no início).

   **Via PowerShell:**
   ```powershell
   # Substitua o caminho de origem pelo caminho real do repositório no seu sistema
   Copy-Item -Path "C:\Caminho\Para\O\Repositorio\tools\wsl\wslconf-optimized\wslconfig" -Destination "$HOME\.wslconfig"
   ```

   *Nota:* Se você estiver dentro do WSL, você pode copiar diretamente para a pasta do Windows:
   ```bash
   # Obtenha o nome do seu usuário do Windows
   WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
   cp wslconfig "/mnt/c/Users/$WIN_USER/.wslconfig"
   ```

3. Abra o arquivo no seu editor e substitua `SEU_USER` pelo seu nome de usuário do Windows no caminho do arquivo de swap:
   ```ini
   swapfile=C:\\Users\\SEU_USER\\AppData\\Local\\Temp\\wsl-swap.vhdx
   ```

4. Reinicie o WSL para aplicar as novas configurações. No PowerShell do Windows, execute:
   ```powershell
   wsl --shutdown
   ```
