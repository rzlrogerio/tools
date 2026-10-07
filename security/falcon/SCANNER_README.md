# CrowdStrike Local Image Scanner

Ferramenta para escanear imagens Docker locais com CrowdStrike Falcon Container Security (FCS).

## Instalação

### Pré-requisitos
- Python 3.8+
- Docker/Podman instalado
- AWS CLI configurado (credenciais)
- Acesso aos secrets no AWS Secrets Manager

### Como usar

#### Linux/macOS

```bash
# Opção 1: usar o shell script (recomendado)
./scan_local_image.sh 6da180ef5035

# Opção 2: usar diretamente com python
python3 scan_local_image.py 6da180ef5035

# Opção 3: usar o wrapper Python (multiplataforma)
python3 scan_local_image_runner.py 6da180ef5035
```

#### Windows (PowerShell, CMD ou Git Bash)

```bash
# Opção 1: usar o script batch
scan_local_image.bat 6da180ef5035

# Opção 2: usar diretamente com python
python scan_local_image.py 6da180ef5035

# Opção 3: usar o wrapper Python (multiplataforma)
python scan_local_image_runner.py 6da180ef5035
```

## Opções de linha de comando

```
usage: scan_local_image.py [-h] [--output-dir OUTPUT_DIR] [--platform PLATFORM]
                           [--fcs-version FCS_VERSION] [--report-limit REPORT_LIMIT]
                           [--minimum-severity MINIMUM_SEVERITY]
                           [--minimum-score MINIMUM_SCORE]
                           [--fcs-timeout FCS_TIMEOUT]
                           [--falcon-client-id FALCON_CLIENT_ID]
                           [--falcon-region FALCON_REGION]
                           [--aws-region AWS_REGION]
                           [--secret-arn SECRET_ARN]
                           [--client-id-secret-arn CLIENT_ID_SECRET_ARN]
                           image

Escanear imagem Docker local com CrowdStrike Falcon Container Security.

positional arguments:
  image                 Image ID ou tag (ex.: 6da180ef5035, nginx:latest)

optional arguments:
  -h, --help            Mostrar help
  --output-dir OUTPUT_DIR
                        Diretório para salvar relatórios (padrão: ~/Documents/scan-image)
  --platform PLATFORM   Platform opcional (ex.: linux/amd64)
  --fcs-version FCS_VERSION
                        Versão do FCS CLI (padrão: latest)
  --report-limit REPORT_LIMIT
                        Máximo de findings no Markdown (padrão: 30)
  --minimum-severity MINIMUM_SEVERITY
                        Severidade mínima (low, medium, high, critical)
  --minimum-score MINIMUM_SCORE
                        Score CVSS mínimo (0.0-10.0)
  --fcs-timeout FCS_TIMEOUT
                        Timeout em segundos para FCS (padrão: 600)
  --falcon-client-id FALCON_CLIENT_ID
                        Client ID do Falcon (autodetectado se omitido)
  --falcon-region FALCON_REGION
                        Região Falcon (padrão: us-2)
  --aws-region AWS_REGION
                        Região AWS para Secrets Manager (padrão: us-east-1)
  --secret-arn SECRET_ARN
                        ARN do secret para client_secret (padrão: FALCON_SCAN/FALCON_CLIENT_SECRET)
  --client-id-secret-arn CLIENT_ID_SECRET_ARN
                        ARN do secret para client_id (padrão: FALCON_SCAN/FALCON_CLIENT_ID)
```

## Exemplos

### Scan básico
```bash
./scan_local_image.sh 6da180ef5035
```

### Scan com severidade mínima HIGH
```bash
./scan_local_image.sh nginx:latest --minimum-severity high
```

### Scan com timeout estendido
```bash
./scan_local_image.sh 6da180ef5035 --fcs-timeout 1200
```

### Scan com custom output directory
```bash
./scan_local_image.sh 6da180ef5035 --output-dir /tmp/scans
```

## Saída

O script gera um relatório Markdown com:
- Status do scan (Passed/Failed)
- Versão do FCS CLI
- Tabela de CVEs encontradas (com CVE ID, Severidade, CVSS, Package, Versão instalada, Fix disponível, Recomendação, Descrição)
- Relatórios salvos em `~/Documents/scan-image/` ou diretório customizado

Exemplo:
```
scan-6da180ef5035-20260429-112804.md   (18 KB)
```

## Segurança

- Credenciais do Falcon são obtidas automaticamente do AWS Secrets Manager
- Variáveis sensíveis (FCS_CLIENT_ID, FCS_CLIENT_SECRET) são zeradas após o scan
- Arquivos JSON temporários são deletados (apenas Markdown é retido)
- Imagens Docker são cacheadas em `~/.cache/base-images-scan-image/tar-export/` para reutilização

## Troubleshooting

### Python not found
- Windows: Instale Python de https://www.python.org
- Mac: `brew install python3`
- Linux: `apt install python3` ou `yum install python3`

### Docker not found
- Windows: Instale Docker Desktop
- Mac: `brew install docker`
- Linux: `apt install docker.io` ou `yum install docker`

### AWS credentials not found
- Configure AWS CLI: `aws configure`
- Ou use variáveis de ambiente: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

### FCS timeout
- Use `--fcs-timeout` com valor maior (padrão: 600 segundos)
- Para imagens grandes, considere aumentar para 1200+
