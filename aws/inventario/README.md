# AWS Inventory Scripts

Toolkit para coletar e consultar o inventário de recursos na conta AWS.

## Componentes

- `get-inventory.py`: Script principal com dois subcomandos:
  - `collect`: coleta o inventário via Resource Groups Tagging API e gera relatórios por região em JSON e Excel (`report-<account>_<regiao>.json/.xlsx`).
  - `query`: consulta relatórios existentes filtrando por serviço ou tipo específico.
- `get-inventory-detailed.py`: Variante que, além dos dados padrão, enriquece recursos das famílias EC2, RDS, Lambda, SQS e SNS com informações de tamanho/capacidade (p. ex. tipo de instância, memória, armazenamento) e inclui essas colunas nos relatórios.
- `get-inventory.sh` (legado): coleta básica via CloudFormation + AWS Config. Utilize apenas se precisar de compatibilidade antiga.

## Requisitos

- Python 3.9+ recomendado.
- Dependências instaladas com `pip install -r requirements.txt` (inclui `boto3` e `openpyxl`).
- AWS CLI ou variáveis de ambiente configuradas com credenciais/permissões adequadas.

## Uso rápido

```bash
# Criar e ativar ambiente virtual (opcional)
python3 -m venv .venv
source .venv/bin/activate

# Instalar dependências
pip install -r requirements.txt

# Coletar inventário padrão (todas as regiões suportadas)
python3 get-inventory.py collect

# Coletar inventário detalhado (com informações de tamanho)
python3 get-inventory-detailed.py collect

# Coletar somente em regiões específicas
python3 get-inventory-detailed.py collect --regions us-east-1 sa-east-1

# Consultar recursos EC2 já coletados (versão padrão)
python3 get-inventory.py query ec2

# Consultar recursos EC2 com metadados de tamanho (versão detalhada)
python3 get-inventory-detailed.py query ec2

# Consultar apenas instâncias EC2 na região us-east-1
python3 get-inventory.py query ec2:instance --regions us-east-1
```

Os arquivos são gravados no diretório definido por `--output-dir` (padrão `~/Download/inventario/aws`).

## Consultas com jq

O subcomando `collect` continua gerando um JSON por região (`report-<account_id>_<regiao>.json`). O arquivo é um objeto cujas chaves seguem o formato `service:resource`. Exemplos:

```bash
# Listar instâncias EC2
jq '(."ec2:instance" // [])[] | {arn, tags}' /tmp/lab/inventory/report-123456789012_sa-east-1.json

# Obter somente os ARNs de bancos RDS
jq '(."rds:db" // [])[] | .arn' /tmp/lab/inventory/report-123456789012_sa-east-1.json

# Contar funções Lambda
jq '((."lambda:function" // []) | length)' /tmp/lab/inventory/report-123456789012_sa-east-1.json

# Filtrar recursos por tag (ex.: ambiente=prod)
jq '(."ec2:instance" // [])[] | select(.tags.ambiente == "prod")' /tmp/lab/inventory/report-123456789012_sa-east-1.json
```

Troque `123456789012` e `sa-east-1` pelo ID real da conta e pela região usada. O operador `// []` evita erros quando não há recursos para a chave.

## Consulta via script

O subcomando `query` lê os relatórios JSON do diretório selecionado e imprime cada recurso correspondente ao filtro como uma linha JSON compacta (`account`, `region`, `type`, `arn`, `resource_name`, `tags`).

```bash
# Buscar qualquer recurso do serviço EC2 (instâncias, EIP, NAT, SG...)
python3 get-inventory.py query ec2

# Buscar apenas NAT Gateways (tipo completo)
python3 get-inventory.py query ec2:natgateway --regions sa-east-1

# Direcionar saída para um arquivo
python3 get-inventory.py query rds:db > rds.jsonl
```

## Relatórios em Excel

Ambos os scripts geram, por região, um arquivo `report-<account>_<regiao>.xlsx` com abas:

- `Recursos`: lista completa (`resource_type`, `family`, `resource_name`, `size`, `arn`, `tags`).
- `Resumo`: contagem por tipo e família.
- Abas por serviço (`EC2`, `RDS`, `Lambda`, `SQS`, `SNS`) contendo apenas os recursos daquela família e um quadro de contagem.

A versão detalhada preenche a coluna `size` (por exemplo `m5.large, 8 GiB RAM, 2 vCPU` para instâncias EC2, `db.t3.medium | 20 GiB` para RDS, `256 MB` para Lambda, etc.). Abra o arquivo no Excel/LibreOffice para filtrar, ordenar ou compartilhar os dados diretamente.

## Observações

- A Resource Groups Tagging API retorna somente recursos tagueados; itens sem tags não aparecerão.
- Use `--profile` para escolher credenciais específicas (`python3 get-inventory.py collect --profile prod`).
- O diretório de saída pode ser redefinido via `--output-dir` ou variável `OUTPUT_DIR`.
- Relatórios gerados com versões anteriores dos scripts podem não conter as colunas `family`, `size` ou os metadados adicionais; execute novamente o subcomando `collect` (preferencialmente da variante detalhada) para atualizar os arquivos existentes.
