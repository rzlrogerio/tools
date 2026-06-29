# WSL Backup Solution - Sync to OneDrive

Esta solução automatiza o backup de arquivos e diretórios do WSL para o OneDrive, utilizando rsync e cron para sincronização periódica.

## 📋 Visão Geral

O script `sync-onedrive.sh` sincroniza automaticamente seus arquivos de trabalho, configurações e dotfiles do WSL para uma pasta no OneDrive (acessível via Windows), garantindo backup contínuo dos seus dados.

## 🏗️ Arquitetura da Solução

### Estrutura de Diretórios com Links Simbólicos

A solução utiliza links simbólicos para tornar o acesso transparente:

```
$HOME/
├── 1-work/                      # Diretório de trabalho principal (WSL)
├── 1-work-windows/              # Link simbólico → OneDrive Windows
└── bin/                         # Link simbólico → 1-work/bin/
```

**Vantagens:**

- Acesso transparente aos arquivos sincronizados
- Portabilidade entre WSL e Windows
- Facilita comandos e navegação

## 🚀 Instalação e Configuração

### Pré-requisitos

- WSL (Windows Subsystem for Linux)
- OneDrive instalado e configurado no Windows
- rsync instalado no WSL
- cron instalado no WSL

### Passo 1: Identificar o Caminho do OneDrive

Encontre o caminho do seu OneDrive no Windows. Geralmente está em:

```bash
/mnt/c/Users/TROQUE_SEU_USER/OneDrive - TROQUE_SUA_EMPRESA/
```

Exemplo:

```bash
/mnt/c/Users/TROQUE_SEU_USER/OneDrive - Minha Empresa/1-work
```

### Passo 2: Criar Links Simbólicos

Crie os links simbólicos adaptados ao seu ambiente:

```bash
# Link para o diretório OneDrive (destino do backup)
ln -s "/mnt/c/Users/TROQUE_SEU_USER/OneDrive - TROQUE_SUA_EMPRESA/1-work" ~/1-work-windows

# Link para facilitar acesso aos seus scripts
ln -s ~/1-work/bin ~/bin
```

**Verificação:**

```bash
ls -la ~ | grep "work\|bin"
```

Você deve ver algo como:

```
lrwxrwxrwx  1 user user   63 Oct 23 13:12 1-work-windows -> /mnt/c/Users/TROQUE_SEU_USER/OneDrive - TROQUE_SUA_EMPRESA/1-work
lrwxrwxrwx  1 user user   10 Oct 23 13:18 bin -> 1-work/bin
```

### Passo 3: Configurar o Script

1. **Copie o script para seu diretório de binários:**

   ```bash
   mkdir -p ~/1-work/bin
   cp sync-onedrive.sh ~/1-work/bin/
   chmod +x ~/1-work/bin/sync-onedrive.sh
   ```

2. **Adapte as variáveis no script** `~/1-work/bin/sync-onedrive.sh`:

   ```bash
   # Ajuste os caminhos de origem conforme seu ambiente
   SOURCES=(
       "$HOME/1-work/"                              # diretório principal de trabalho
       "$HOME/bin/"                                 # scripts e tools
       "$HOME/.oh-my-zsh"                           # tema oh-my-zsh
       "$HOME/.zshrc"                               # configuração zsh
       "$HOME/.vimrc"                               # configuração vim
       "$HOME/.vim/"                                # diretório .vim
       "$HOME/.config/Code/User/settings.json"     # configurações VSCode
       "$HOME/.zsh_history"                         # histórico zsh
       "$HOME/.aws/config"                          # config AWS
       "$HOME/.ssh/id_rsa.pub"                      # chave pública SSH
   )

   # Ajuste o destino (link simbólico para OneDrive)
   DESTINO_BASE="$HOME/1-work-windows"
   ```

3. **Teste o script manualmente:**
   ```bash
   ~/bin/sync-onedrive.sh
   ```

### Passo 4: Configurar Cron para Execução Automática

1. **Edite o crontab:**

   ```bash
   crontab -e
   ```

2. **Adicione a linha para execução a cada 5 minutos:**

   ```cron
   # Backup automático para OneDrive a cada 5 minutos
   */5 * * * * $HOME/bin/sync-onedrive.sh >/dev/null 2>&1
   ```

3. **Verifique a configuração:**

   ```bash
   crontab -l
   ```

4. **Certifique-se de que o cron está rodando:**
   ```bash
   sudo service cron status
   # ou
   sudo systemctl status cron
   ```

## 📁 Arquivos da Solução

| Arquivo               | Descrição                                   |
| --------------------- | ------------------------------------------- |
| `sync-onedrive.sh`    | Script principal de sincronização via rsync |
| `crontab-example.txt` | Exemplo de configuração do crontab          |
| `lista-links.txt`     | Referência de links simbólicos criados      |
| `README.md`           | Esta documentação                           |

## ⚙️ Funcionalidades do Script

### Proteção contra Execução Simultânea

O script usa um lock file (`/tmp/rsync_work_sync.lock`) para evitar execuções concorrentes.

### Exclusões Automáticas

O script já exclui automaticamente:

- `.git/` - repositórios Git
- `.terraform/` - cache Terraform
- `node_modules/` - dependências Node.js
- `__pycache__/`, `*.pyc`, `*.pyo` - cache Python
- `.vscode/`, `.idea/` - IDEs
- `build/`, `dist/`, `target/` - artefatos de build
- Arquivos temporários e logs

### Opções do rsync

- `-a` (archive): preserva permissões, timestamps, links simbólicos
- `-v` (verbose): modo detalhado
- `-h` (human-readable): tamanhos legíveis
- `--delete`: remove arquivos no destino que não existem na origem
- `--progress`: mostra progresso da transferência

## 🔧 Personalização

### Adicionar Novos Diretórios/Arquivos

Edite o array `SOURCES` no script:

```bash
SOURCES=(
    "$HOME/meu-novo-diretorio/"
    "$HOME/.minha-config"
    # ... outros itens
)
```

### Alterar Frequência do Backup

Modifique a linha do crontab:

```cron
# A cada 10 minutos
*/10 * * * * $HOME/bin/sync-onedrive.sh >/dev/null 2>&1

# A cada 30 minutos
*/30 * * * * $HOME/bin/sync-onedrive.sh >/dev/null 2>&1

# A cada hora
0 * * * * $HOME/bin/sync-onedrive.sh >/dev/null 2>&1

# Diariamente às 2h da manhã
0 2 * * * $HOME/bin/sync-onedrive.sh >/dev/null 2>&1
```

### Adicionar Mais Exclusões

Adicione ao array `RSYNC_OPTS`:

```bash
RSYNC_OPTS=(
    # ... opções existentes ...
    --exclude='meu-diretorio-grande'
    --exclude='*.iso'
)
```

## 🐛 Troubleshooting

### O cron não está executando

```bash
# Verificar se o cron está rodando
sudo service cron status

# Iniciar o cron
sudo service cron start

# Ver logs do cron
grep CRON /var/log/syslog
```

### Verificar última execução

```bash
# Ver logs do script (se redirecionado)
tail -f /tmp/rsync_work_sync.log

# Verificar se lock file existe (script em execução)
ls -la /tmp/rsync_work_sync.lock
```

### Permissões negadas

```bash
# Garantir que o script é executável
chmod +x ~/bin/sync-onedrive.sh

# Verificar permissões do OneDrive
ls -la ~/1-work-windows
```

### OneDrive não sincronizando

- Verifique se o OneDrive está rodando no Windows
- Confirme que o link simbólico aponta para o local correto
- Verifique se há espaço suficiente no OneDrive

## 📊 Monitoramento

### Verificar tamanho do backup

```bash
du -sh ~/1-work-windows
```

### Ver última modificação

```bash
ls -lth ~/1-work-windows | head -20
```

### Logs detalhados

Para debug, execute manualmente com log:

```bash
~/bin/sync-onedrive.sh 2>&1 | tee /tmp/sync-debug.log
```

## 🔐 Segurança

### Cuidados Importantes

- ⚠️ **Não sincronize chaves privadas SSH** (apenas `.pub`)
- ⚠️ **Não sincronize senhas ou tokens em plain text**
- ⚠️ **Revise o array `SOURCES` antes de adicionar novos itens**
- ✅ Use arquivos `.env` ou ferramentas como `pass`, `vault` para secrets
- ✅ Adicione diretórios sensíveis ao `--exclude`

## 📝 Notas Adicionais

- O OneDrive deve estar ativo no Windows para sincronização funcionar
- Sincronizações grandes podem demorar na primeira execução
- O `--delete` remove arquivos no destino não presentes na origem
- Links simbólicos dentro dos diretórios sincronizados são preservados

## 🤝 Contribuindo

Para melhorias ou sugestões:

1. Teste suas modificações
2. Documente as mudanças
3. Considere casos de uso diferentes

## 📄 Licença
Use com cuidado! :)
---

**Última atualização:** Novembro 2024
