# WSL SSH Key Sync

Este utilitário automatiza a cópia e a configuração das chaves SSH do Windows para o ambiente WSL, garantindo que as permissões de segurança sejam aplicadas corretamente.

## 📋 O Problema

Ao copiar manualmente as chaves SSH do Windows para o WSL (por exemplo, de `C:\Users\usuario\.ssh` para `~/.ssh`), é comum que os arquivos fiquem com permissões muito abertas (como `0777` ou `0644` para chaves privadas). 

O cliente SSH do Linux exige estritamente que as chaves privadas sejam acessíveis apenas pelo proprietário (permissão `0600`). Se as permissões estiverem incorretas, o SSH falhará com um erro semelhante a:
> *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*
> *@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @*
> *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*
> *Permissions 0777 for '/home/user/.ssh/id_rsa' are too open.*

## 🚀 Como Funciona o Script

O script `sync-ssh.sh`:
1. Identifica automaticamente o nome do usuário do Windows ativo.
2. Localiza a pasta `.ssh` do Windows em `/mnt/c/Users/USERNAME/.ssh`.
3. Garante a existência do diretório `~/.ssh` no WSL com permissões adequadas (`0700`).
4. Copia as chaves identificadas (chaves privadas, públicas, arquivo `config` e `authorized_keys`).
5. Aplica a permissão `0600` para as chaves privadas e `0644` para os arquivos públicos/configurações.

## 💻 Como Usar

1. Torne o script executável:
   ```bash
   chmod +x sync-ssh.sh
   ```

2. Execute o script:
   ```bash
   ./sync-ssh.sh
   ```

## 🛠️ Requisitos
- WSL2 rodando no Windows.
- Chaves SSH já geradas e configuradas no Windows.
