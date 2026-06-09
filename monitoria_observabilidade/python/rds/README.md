# Coletor de Métricas RDS para OpenTelemetry

Este projeto contém um script Python (`get_rds_status_infra.py`) para coletar métricas de instâncias AWS RDS via CloudWatch e enviá-las para um backend compatível com OpenTelemetry (OTLP).

## Índice

- Funcionalidades
- Pré-requisitos
- Instalação e Configuração
- Configuração na AWS
  - 1. Acesso na Mesma Conta
  - 2. Acesso Cross-Account
- Como Usar
- Exemplos de Orquestração (Kubernetes)
- Métricas e Dashboards (Grafana)
- Desenvolvimento (Lint e Pre-commit)

## Funcionalidades

- **Coleta Abrangente**: Coleta as principais métricas do CloudWatch para instâncias RDS.
- **Métricas Customizadas**: Calcula métricas úteis como `PercentFreeStorage` e `PercentUsedMemory`.
- **Suporte a Múltiplos Motores**: Templates de métricas separados para MySQL, PostgreSQL, MariaDB, Oracle e SQL Server.
- **Cross-Account**: Suporte nativo para coletar métricas de outras contas AWS através de `AssumeRole`.
- **Padrão Aberto**: Utiliza OpenTelemetry (OTLP) para exportar métricas, garantindo compatibilidade com diversos backends (Prometheus, Grafana Cloud, etc.).
- **Seguro**: Inclui um mecanismo de lock para prevenir execuções simultâneas (ideal para `cron`).
## Pré-requisitos

- Python 3.8+
- Credenciais AWS configuradas (via `~/.aws/credentials` ou variáveis de ambiente).
- Um endpoint OTLP/gRPC acessível para receber as métricas (ex: OpenTelemetry Collector, Grafana Agent).

## Instalação e Configuração

1.  **Clone o repositório:**
    ```bash
    git clone <url-do-repositorio>
    cd <diretorio-do-repositorio>
    ```

2.  **Crie um ambiente virtual e instale as dependências:**
    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    ```
    > Para informações sobre como configurar o ambiente de desenvolvimento (lint, pre-commit), veja a seção Desenvolvimento.

## Configuração na AWS

O script pode ser executado de duas formas: acessando recursos na mesma conta AWS ou em contas diferentes (cross-account).

### 1. Acesso na Mesma Conta

Se você executar o script usando credenciais locais (ex: um perfil AWS configurado), não é necessário criar uma role adicional. Apenas garanta que as credenciais tenham as seguintes permissões mínimas:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:GetMetricData",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "rds:DescribeDBInstances",
                "rds:DescribeDBClusters"
            ],
            "Resource": "*"
        }
    ]
}
```

### 2. Acesso Cross-Account

Este é o cenário ideal para monitoramento centralizado, onde uma conta de "monitoramento" assume uma role em cada conta-alvo para coletar as métricas.

Na **conta-alvo** (onde estão as instâncias RDS), crie uma IAM Role com duas policies:

**A. Policy de Permissões (Permissions Policy):**
Use o mesmo JSON da seção anterior para conceder as permissões necessárias para CloudWatch e RDS.

**B. Política de Confiança (Trust Policy):**
Esta política permite que a conta de monitoramento assuma a role.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::MONITORING_ACCOUNT_ID:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }
    ]
}
```
> Substitua `MONITORING_ACCOUNT_ID` pelo ID da conta AWS que fará a coleta.

#### Referenciando a Role no Script

O script procura uma variável de ambiente no formato `ACCOUNTNAME_ROLE` para encontrar o ARN da role a ser assumida.

- `ACCOUNTNAME` é o valor passado no argumento `--account-name`, convertido para maiúsculas e com hífens (`-`) trocados por underscores (`_`).
- Exemplo: para `--account-name teste-prd`, o script procurará a variável de ambiente `TESTE_PRD_ROLE`.

**Exemplo de como definir a variável de ambiente:**
```bash
# Recomendamos adicionar um sufixo numérico aleatório ao nome da role para dificultar enumeração.
export TESTE_PRD_ROLE="arn:aws:iam::123456789012:role/RoleParaMonitoramento-8472"
```

## Como Usar

**Exemplo 1: Coletar métricas de uma conta-alvo usando `AssumeRole`**

```bash
# Certifique-se de que a variável de ambiente TESTE_PRD_ROLE está definida
./get_rds_status_infra.py \
  --account-name teste-prd \
  --region us-east-1 \
  --engine mysql \
  --period 300
```

**Exemplo 2: Coletar métricas da conta local (sem `AssumeRole`)**

```bash
./get_rds_status_infra.py \
  --account-name none \
  --region us-east-1 \
  --engine postgres \
  --period 300
```
> **Nota**: O argumento `--period` é definido em segundos (ex: 3600 = 1 hora).

## Métricas e Dashboards (Grafana)

O script envia métricas para o endpoint OTLP com o nome `bu_teste_rds_metrics` e os seguintes atributos (labels):

- `key`: Nome da métrica (ex: `CPUUtilization`).
- `AGR`: O identificador da instância de banco de dados (`DBInstanceIdentifier`).
- `ac_name`: Nome da conta (`--account-name`).
- `region`: Região AWS.
- `engine`: Motor do banco de dados.
- `bu`: Unidade de negócio (fixo como "buteste" no script).

Se você estiver usando um backend compatível com PromQL (como Prometheus ou Grafana Mimir), pode usar as queries abaixo como ponto de partida para seus dashboards.

> **Importante**: O script multiplica os valores por 100 antes de enviá-los. Para obter o valor percentual original, divida por 100 na sua query.

#### Exemplos de Queries PromQL

**Média da CPU (%) da instância `mydb` na última hora:**
```promql
avg_over_time(bu_teste_rds_metrics{key="CPUUtilization", AGR="mydb"}[1h]) / 100
```

**Máximo de conexões na instância `mydb` na última hora:**
```promql
max_over_time(buteste_rds_metrics{key="DatabaseConnections", AGR="mydb"}[1h]) / 100
```

**Percentual de armazenamento livre (métrica `PercentFreeStorage`):**
```promql
avg_over_time(buteste_rds_metrics{key="PercentFreeStorage", AGR="mydb"}[6h]) / 100
```

**Percentual de memória usada (métrica `PercentUsedMemory`):**
```promql
avg_over_time(buteste_rds_metrics{key="PercentUsedMemory", AGR="mydb"}[1h]) / 100
```

## Desenvolvimento (Lint e Pre-commit)

Para garantir a qualidade e a consistência do código, o projeto utiliza `black`, `isort` e `ruff`. A configuração está gerenciada via `pre-commit`.

1.  **Instale o pre-commit:**
    ```bash
    pip install pre-commit
    ```

2.  **Instale os hooks no seu clone local:**
    ```bash
    pre-commit install
    ```

Agora, os hooks serão executados automaticamente a cada `git commit`, formatando o código e verificando por erros.

Para executar as verificações em todos os arquivos manualmente:
```bash
pre-commit run --all-files
```

Para integração com CI/CD, adicione um passo no seu pipeline para executar `pre-commit run --all-files`.

> **Nota**: O argumento `--period` é definido em segundos (ex: 3600 = 1 hora).

## Exemplos de Orquestração (Kubernetes)

Para executar este coletor de forma agendada em um ambiente Kubernetes, você pode usar um `CronJob`. O arquivo `cronjob.yaml` neste diretório contém um exemplo pronto para uso que executa o script a cada 5 minutos.

### Passos para Implantação

1.  **Criar uma Imagem Docker:**
    Primeiro, você precisa containerizar a aplicação. Crie um `Dockerfile` que instale as dependências do `requirements.txt` e copie o script.

    *Exemplo de Dockerfile:*
    ```dockerfile
    FROM python:3.9-slim

    WORKDIR /app

    COPY requirements.txt .
    RUN pip install --no-cache-dir -r requirements.txt

    COPY get_rds_status_infra.py .
    
    # O comando para executar o script será definido no CronJob
    ```

2.  **Publicar a Imagem:**
    Compile e envie sua imagem para um registro de contêiner (Docker Hub, Amazon ECR, GCR, etc.) que seja acessível pelo seu cluster Kubernetes.
    ```bash
    docker build -t seu-registro/seu-coletor-rds:latest .
    docker push seu-registro/seu-coletor-rds:latest
    ```

3.  **Configurar Credenciais AWS (se necessário):**
    O `cronjob.yaml` de exemplo espera que as credenciais da AWS estejam em um Secret do Kubernetes chamado `aws-credentials` no namespace `monitoring`. Se você não estiver usando um método de autenticação alternativo (como IRSA), crie o Secret:
    ```bash
    # Certifique-se de que o namespace 'monitoring' existe: kubectl create ns monitoring
    kubectl create secret generic aws-credentials \
      --from-literal=aws_access_key_id=SUA_ACCESS_KEY \
      --from-literal=aws_secret_access_key=SUA_SECRET_KEY \
      -n monitoring
    ```
    > **Nota de Segurança**: Para ambientes de produção, é altamente recomendado usar uma abordagem mais segura para gerenciar credenciais, como IAM Roles for Service Accounts (IRSA) em clusters EKS.

4.  **Personalizar e Aplicar o `cronjob.yaml`:**
    Abra o arquivo `cronjob.yaml` e edite os campos `image` e `command` conforme necessário. Depois, aplique-o ao seu cluster:
    ```bash
    kubectl apply -f cronjob.yaml -n monitoring
    ```




