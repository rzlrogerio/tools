# CrowdStrike Falcon Local Image Scanner

Utilitário para executar localmente scans de imagens de container com o
CrowdStrike Falcon Container Security (FCS). A imagem é lida do Docker local,
evitando fazer o scan por meio de um runner do GitHub Actions e ajudando a
reduzir o tempo e o custo de execuções de CI.

O scanner usa o FCS CLI oficial e as credenciais da API Falcon. Ele não substitui
a GitHub Action: oferece um fluxo local para analisar uma imagem antes ou fora
da pipeline.

## Navegação

- [Guia de uso, opções e troubleshooting](./SCANNER_README.md)
- [Wrappers e instruções por sistema operacional](./WRAPPER_MULTIPLATAFORMA.md)

## Requisitos

- Python 3.8 ou superior
- Docker instalado e em execução; a imagem a ser analisada deve estar disponível localmente
- AWS CLI configurado com permissão para ler os secrets no AWS Secrets Manager
- Secrets com o Falcon Client ID e Client Secret
- Acesso de rede à API CrowdStrike para autenticação e download do FCS CLI

## Início rápido

Na pasta deste utilitário, execute o scan passando o nome, a tag ou o ID de uma
imagem existente no Docker local:

### Linux e macOS

```bash
./scan_local_image.sh nginx:latest
```

### Windows

```bat
scan_local_image.bat nginx:latest
```

Também é possível executar o script Python diretamente:

```bash
python3 scan_local_image.py nginx:latest
```

No Windows, use `python` no lugar de `python3`.

## Como funciona

1. Confirma que a imagem está disponível localmente no Docker.
2. Exporta a imagem para um arquivo tar local, sem solicitar que o scanner a baixe de um registry.
3. Obtém as credenciais do Falcon no AWS Secrets Manager, salvo quando o Client ID é informado por opção ou variável de ambiente.
4. Obtém e executa o FCS CLI oficial para analisar a imagem.
5. Salva um relatório Markdown com o status do scan e os findings encontrados.

O relatório é salvo, por padrão, em `~/Documents/scan-image/`. O tar e os
arquivos JSON temporários são removidos ao final do scan. O FCS CLI baixado pode
ser reutilizado do cache local.

## Exemplos de relatórios

Não há relatórios reais versionados junto com o utilitário. Os exemplos abaixo
são **simulações para demonstrar o formato e o fluxo**: os totais e os dados de
CVE são fictícios e não representam resultados de uma execução do CrowdStrike.
Os resultados variam conforme a data, a arquitetura, os pacotes presentes e a
versão do banco de vulnerabilidades do Falcon.

### Comparar `python:3.13` e `python:3.13-alpine`

Baixe as duas imagens e execute o scanner em cada uma:

```bash
docker pull python:3.13
docker pull python:3.13-alpine

./scan_local_image.sh python:3.13
./scan_local_image.sh python:3.13-alpine
```

Cada execução gera um relatório Markdown em seu próprio subdiretório, dentro de
`~/Documents/scan-image/`. Um resumo **simulado** dos relatórios poderia ser:

| Imagem | Critical | High | Medium | Low | Total |
|--------|---------:|-----:|-------:|----:|------:|
| `python:3.13` | 1 | 4 | 7 | 3 | 15 |
| `python:3.13-alpine` | 0 | 2 | 4 | 2 | 8 |

Um trecho ilustrativo de um relatório individual tem esta estrutura:

```markdown
# CrowdStrike Security Scan

- Image: `python:3.13`
- Status: `Failed`
- FCS Version: `x.y.z`
- Exit Code: `1`

## Vulnerability Details

| CVE ID | Severity | CVSS Score | Package | Installed | Fixed In | Recommendation | Description |
|--------|----------|------------|---------|-----------|----------|----------------|-------------|
| CVE-20XX-XXXX | HIGH | 8.1 | pacote-exemplo | 1.0.0 | 1.0.1 | Atualizar o pacote | Finding ilustrativo; não corresponde a uma CVE real |
```

Os identificadores e valores dessa amostra são placeholders, não findings reais.
O status e o código de saída também dependem do resultado e da política de
severidade configurada no FCS CLI.

### Acompanhar a redução de CVEs após correções

Depois de revisar os findings e atualizar a imagem (por exemplo, atualizando
pacotes ou a imagem-base no Dockerfile), reconstrua-a com a **mesma tag** e rode
o scanner novamente. O relatório seguinte permite verificar se os findings
diminuíram. Exemplo de resumo **inteiramente simulado**:

| Imagem/tag | Etapa | Critical | High | Medium | Low | Total |
|------------|-------|---------:|-----:|-------:|----:|------:|
| `python:3.13` | Antes das correções | 1 | 4 | 7 | 3 | 15 |
| `python:3.13` | Depois das correções | 0 | 1 | 3 | 2 | 6 |
| `python:3.13-alpine` | Antes das correções | 0 | 2 | 4 | 2 | 8 |
| `python:3.13-alpine` | Depois das correções | 0 | 1 | 2 | 1 | 4 |

A comparação automática do utilitário é gerada quando há pelo menos dois
relatórios para o mesmo nome de imagem no respectivo subdiretório de saída. Ela
resume as contagens de CVEs por severidade e é sobrescrita a cada dia para essa
imagem. Como `python:3.13` e `python:3.13-alpine` são nomes distintos, o scanner
gera comparações separadas para eles; a tabela conjunta acima é um exemplo
manual para facilitar a análise lado a lado, não um arquivo produzido
automaticamente pelo scanner.

As contagens da comparação automática são extraídas das linhas de findings
presentes nos relatórios Markdown. Portanto, estão sujeitas ao limite configurado
por `--report-limit` e não devem ser interpretadas como total absoluto quando o
relatório tiver sido truncado.

## Documentação

Consulte o [guia de uso](./SCANNER_README.md) para ver todas as opções de linha
de comando, exemplos, formato dos relatórios e troubleshooting. Para escolher o
wrapper adequado ou consultar instruções específicas de Linux, macOS e Windows,
veja [wrappers multiplataforma](./WRAPPER_MULTIPLATAFORMA.md).
