# AWS Config Directory

Este diretório contém arquivos de configuração relacionados ao acesso e gerenciamento de contas AWS utilizando perfis SSO (Single Sign-On).

## Arquivos

- `config`: Arquivo de configuração de perfis AWS. Cada seção `[profile <nome>]` define um perfil de acesso, incluindo informações como:
  - `sso_start_url`: URL de início do SSO.
  - `sso_region`: Região AWS para autenticação SSO.
  - `sso_account_id`: ID da conta AWS.
  - `sso_role_name`: Nome do papel (role) a ser assumido.
  - `region`: Região padrão para operações AWS.

## Uso com o script awslogin

O script `awslogin` (localizado no diretório pai) automatiza o processo de login SSO e configuração de clusters EKS. Ele utiliza os perfis definidos neste arquivo `config`.

### Pré-requisitos

**IMPORTANTE:** Antes de usar o script pela primeira vez, é necessário criar o arquivo de backup do kubeconfig:

```sh
cp ~/.kube/config ~/.kube/config-aws
```

Este backup é essencial para o correto funcionamento do script, pois ele permite a alternância entre configurações AWS e Azure sem duplicação de cadastros.

### Executando o script

1. **Listar perfis disponíveis:**

   ```sh
   ./awslogin
   ```

   Exibe todos os perfis configurados no arquivo `config`.

2. **Fazer login em um perfil específico:**
   ```sh
   ./awslogin <nome-do-perfil>
   ```
   Exemplo: `./awslogin sandbox`

### O que o script faz

- Restaura o kubeconfig a partir do backup (`~/.kube/config-aws`)
- Executa logout do SSO anterior
- Realiza login no perfil especificado via SSO (sem browser)
- Busca automaticamente por clusters EKS nas regiões configuradas (sa-east-1 e us-east-1)
- Adiciona os clusters encontrados ao kubeconfig local (evitando duplicações)
- Salva uma nova versão do backup após adicionar os clusters
- Limpa o contexto kubectl ao final

### Exemplo de uso manual (sem o script)

Para configurar manualmente:

```sh
export AWS_CONFIG_FILE=/caminho/para/aws/config
aws sso login --profile <nome-do-perfil>
```

Substitua `<nome-do-perfil>` pelo nome desejado (ex: `sandbox`, `prod`, etc).

---

Mantenha este arquivo atualizado conforme novos perfis forem adicionados ou modificados.

## 📞 Suporte
Chama o "batima" :)

