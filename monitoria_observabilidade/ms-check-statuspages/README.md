# Health Monitor — OpenSearch
# Teste

Script Python unificado que monitora **AWS Health**, **Azure Health** e **Status Pages** de terceiros, enviando documentos JSON para o **OpenSearch** quando há ocorrências ativas.

**Diferença da versão Dynatrace:** só envia dados quando há incidentes/degradação — serviços operacionais não geram documento. Isso permite criar dashboards e alarmes customizados no OpenSearch/Kibana baseados em dados ricos (severidade, região, componentes afetados, etc).

---

## Como usar

```bash
python3 monitor_multi_health.py [--aws] [--azure] [--test] [URL ...]
```

| O que monitorar | Comando |
|---|---|
| Só AWS | `python3 monitor_multi_health.py --aws` |
| Só Azure | `python3 monitor_multi_health.py --azure` |
| Só status pages | `python3 monitor_multi_health.py URL1 URL2` |
| Tudo junto | `python3 monitor_multi_health.py --aws --azure URL1 URL2` |
| Modo teste | `python3 monitor_multi_health.py --aws --azure --test` |

---

## Tecnologias de Status Page Suportadas

O script suporta monitorar cinco tipos principais de tecnologias ou fontes de dados de status:

### 1. Atlassian Statuspage (JSON API)
* **Descrição:** Para provedores que utilizam a infraestrutura padrão do Atlassian Statuspage.
* **Detecção:** URLs terminando em `/api/v2/summary.json`.
* **Como funciona:** Realiza requisições HTTP GET ao endpoint e faz o parse do JSON retornado.
* **Autenticação:** Suporta autenticação global ou por URL através de tokens Bearer ou Basic Auth.
* **Dados extraídos:** Componentes degradados, incidentes ativos e manutenções em andamento.

### 2. StatusCast (HTML Scraping)
* **Descrição:** Monitor especializado para status pages da plataforma StatusCast.
* **Detecção:** Domínios que terminam com `.status.page` ou URLs cadastradas na variável `STATUSCAST_URLS`.
* **Como funciona:** Realiza autenticação via formulário HTTP POST (`/login?handler=login`) usando credenciais, armazena os cookies de sessão e faz raspagem (scraping) do HTML das páginas interna e de calendário.
* **Dados extraídos:** Ocorrências atuais, componentes com problemas e manutenções agendadas para os próximos 7 dias.

### 3. MoneyP / SignalR (BMP)
* **Descrição:** Monitor para extrair métricas de uptime de integrações financeiras e serviços parceiros via SignalR.
* **Detecção:** URLs contendo `moneyp` ou `bmp` no hostname, ou cadastradas em `MONEYP_URLS`.
* **Como funciona:** Negocia e estabelece uma conexão via SignalR long-polling (`/Hubs/DashboardHub/negotiate`), realiza handshake e aguarda as transmissões de dados em tempo real.
* **Dados extraídos:** Uptime percentual de serviços-alvo (Consulta de Saldo, Averbação, Autenticação). Se o uptime cair abaixo de um limite parametrizável (ex: 98%), é gerado um alerta de degradação.

### 4. AWS Health
* **Descrição:** Monitor nativo das ocorrências públicas e globais de serviços da Amazon Web Services.
* **Como funciona:** Consome periodicamente o JSON de eventos públicos da AWS (`https://health.aws.amazon.com/public/currentevents`).
* **Configuração:** Suporta filtragem por regiões usando a variável `AWS_HEALTH_REGIONS` (ex: `sa-east-1,us-east-1`).

### 5. Azure Health
* **Descrição:** Monitor nativo para problemas de saúde e disponibilidade no ecossistema Microsoft Azure.
* **Como funciona:** Consome e faz o parse XML do feed RSS oficial do Azure (`https://rssfeed.azure.status.microsoft/en-us/status/feed`).
* **Dados extraídos:** Varre os títulos e descrições do feed por palavras-chave indicadoras de falhas (`outage`, `incident`, `degraded`, etc.) para reportar incidentes ativos.

---

## Variáveis de ambiente

### OpenSearch (obrigatórias)

```bash
ELK_HOST="https://opensearch.example.com:9200"   # URL do OpenSearch
ELK_USER="admin"                                   # Usuário (basic auth)
ELK_PASSWD="senha"                                 # Senha
ELK_INDEX="health_vendor_status"                   # Índice (padrão: health_vendor_status)
```

### Monitores nativos

```bash
MONITOR_AWS=true       # Equivale a --aws
MONITOR_AZURE=true     # Equivale a --azure
```

### Status Pages

```bash
STATUSPAGE_PUBLIC="url1,url2,url3"              # URLs públicas (sem auth)
STATUSPAGE_PRIVATE="url4,url5"                  # URLs privadas
STATUSPAGE_AUTH_TOKEN="Bearer token_xyz"        # Token global fallback para privadas

# Alias amigável por URL (mesmo padrão de identificador)
STATUSPAGE_ALIAS_STATUS_SNYK_IO="snyk"
STATUSPAGE_ALIAS_WWW_GITHUBSTATUS_COM="github"

# Mapa opcional host/url=alias (fallback quando não existir STATUSPAGE_ALIAS_<IDENTIFIER>)
STATUSPAGE_VENDOR_MAP="status.snyk.io=snyk,https://www.githubstatus.com/api/v2/summary.json=github"

# Credenciais por URL privada (prioridade maior que token global)
STATUSPAGE_TOKEN_STATUS_VENDOR_XYZ_COM="Bearer token_vendor_xyz"
STATUSPAGE_USER_STATUS_VENDOR_ABC_COM="monitor_user"
STATUSPAGE_PASS_STATUS_VENDOR_ABC_COM="monitor_pass"
```

Formato do identificador para variáveis por URL:

- remove http:// ou https://
- remove /api/... do final
- troca ponto e hífen por underscore
- converte para maiúsculo no nome da variável

Exemplo:

- URL: https://status.snyk.io/api/v2/summary.json
- identificador: STATUS_SNYK_IO
- vars possíveis: STATUSPAGE_ALIAS_STATUS_SNYK_IO, STATUSPAGE_TOKEN_STATUS_SNYK_IO

---

## Documento enviado ao OpenSearch

Cada ocorrência gera um documento no índice `health_vendor_status`:

```json
{
  "timestamp":           "2026-03-13T10:00:00Z",
  "vendor":              "snyk",
  "source":              "statuspage",
  "service":             "SNYK",
  "page_name":           "Snyk",
  "status":              "degraded",
  "severity":            1,
  "severity_label":      "degraded",
  "description":         "Partially Degraded Service",
  "event_type":          "incident",
  "incidents_active":    2,
  "maintenances_active": 0,
  "components_degraded": 3,
  "incidents": [
    {"name": "API latency", "status": "investigating", "impact": "minor", "created_at": "..."}
  ],
  "degraded_components": [
    {"name": "API", "status": "degraded_performance"}
  ]
}
```

### Campos por fonte

| Campo | StatusPage | AWS | Azure |
|---|---|---|---|
| `vendor` | nome do vendor | `aws` | `azure` |
| `source` | `statuspage` | `aws_health` | `azure_rss` |
| `region` | — | us-east-1, etc | — |
| `severity` | 0-4 | 1-3 | 2 |
| `incidents` | detalhes | — | itens do RSS |
| `degraded_components` | lista | — | — |

### Valores de severity

| Valor | Label | Significado |
|---|---|---|
| 0 | operational | OK (não envia) |
| 1 | degraded / low | Performance degradada |
| 2 | partial_outage / medium | Outage parcial |
| 3 | major_outage / high | Outage total |
| 4 | maintenance | Manutenção |

### Deduplicação

O documento ID é um MD5 de `vendor + service + region + event_type + timestamp`, usando `op_type=create` para que o OpenSearch rejeite duplicatas (409 Conflict).

---

## Deploy no Kubernetes

### ConfigMap (URLs sem autenticação)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms-mon-statuspage-config
data:
  ELK_INDEX: "health_vendor_status"
  MONITOR_AWS: "true"
  MONITOR_AZURE: "true"
  STATUSPAGE_PUBLIC: "https://status.snyk.io/api/v2/summary.json,https://www.githubstatus.com/api/v2/summary.json"
  STATUSPAGE_ALIAS_STATUS_SNYK_IO: "snyk"
  STATUSPAGE_ALIAS_WWW_GITHUBSTATUS_COM: "github"
```

### ConfigMap (URLs com autenticação)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms-mon-statuspage-config-private
data:
  STATUSPAGE_PRIVATE: "https://status.vendor-xyz.com/api/v2/summary.json,https://status.vendor-abc.com/api/v2/summary.json"

  # Alias amigável por URL
  STATUSPAGE_ALIAS_STATUS_VENDOR_XYZ_COM: "vendor_xyz"
  STATUSPAGE_ALIAS_STATUS_VENDOR_ABC_COM: "vendor_abc"

  # Se não houver token por URL, usa este fallback
  STATUSPAGE_AUTH_TOKEN: "Bearer token_global_fallback"
```

### Secret (OpenSearch + credenciais privadas por URL)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ms-mon-statuspage-secrets
type: Opaque
stringData:
  ELK_HOST: "https://opensearch.internal:9200"
  ELK_USER: "admin"
  ELK_PASSWD: "senha_secreta"

  # Token por URL (prioridade maior que STATUSPAGE_AUTH_TOKEN)
  STATUSPAGE_TOKEN_STATUS_VENDOR_XYZ_COM: "Bearer token_vendor_xyz"

  # Basic auth por URL (alternativa ao token)
  STATUSPAGE_USER_STATUS_VENDOR_ABC_COM: "monitor_user"
  STATUSPAGE_PASS_STATUS_VENDOR_ABC_COM: "monitor_pass"
```

### CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ms-mon-statuspage
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: health-monitor
              image: <REGISTRY>/ms-mon-statuspage:<TAG>
              command: ["python3", "/app/python/monitor_multi_health.py"]
              envFrom:
                - configMapRef:
                    name: ms-mon-statuspage-config
                - secretRef:
                    name: ms-mon-statuspage-secrets
          restartPolicy: OnFailure
```

---

## Queries OpenSearch / Kibana

```json
// Todas as ocorrências das últimas 24h
GET health_vendor_status/_search
{
  "query": {
    "range": { "timestamp": { "gte": "now-24h" } }
  },
  "sort": [{ "timestamp": "desc" }]
}

// Filtrar por vendor
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "vendor.keyword": "aws" } },
        { "range": { "timestamp": { "gte": "now-24h" } } }
      ]
    }
  }
}

// Só severidade alta (>= 2)
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "range": { "severity": { "gte": 2 } } },
        { "range": { "timestamp": { "gte": "now-24h" } } }
      ]
    }
  }
}

// Somente incidentes (sem manutenções)
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "incident" } },
        { "range": { "timestamp": { "gte": "now-7d" } } }
      ]
    }
  },
  "sort": [{ "timestamp": "desc" }]
}

// Somente manutenções
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "maintenance" } },
        { "range": { "timestamp": { "gte": "now-7d" } } }
      ]
    }
  },
  "sort": [{ "timestamp": "desc" }]
}

// Manutenções agendadas (calendário) — próximos 7 dias
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "scheduled_maintenance" } }
      ]
    }
  },
  "sort": [{ "scheduled_start.keyword": "asc" }]
}

// Manutenções agendadas por vendor
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "scheduled_maintenance" } },
        { "term": { "vendor.keyword": "generic-vendor" } }
      ]
    }
  },
  "sort": [{ "scheduled_start.keyword": "asc" }]
}

// Contagem por vendor
GET health_vendor_status/_search
{
  "size": 0,
  "aggs": {
    "by_vendor": { "terms": { "field": "vendor.keyword" } }
  }
}

// Contagem por event_type
GET health_vendor_status/_search
{
  "size": 0,
  "query": {
    "range": { "timestamp": { "gte": "now-7d" } }
  },
  "aggs": {
    "by_event_type": { "terms": { "field": "event_type.keyword" } }
  }
}

// Contagem por source (statuspage, statuscast, aws_health, azure_rss)
GET health_vendor_status/_search
{
  "size": 0,
  "aggs": {
    "by_source": { "terms": { "field": "source.keyword" } }
  }
}

// Timeline de incidentes por vendor (últimos 7 dias)
GET health_vendor_status/_search
{
  "size": 0,
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "incident" } },
        { "range": { "timestamp": { "gte": "now-7d" } } }
      ]
    }
  },
  "aggs": {
    "by_day": {
      "date_histogram": { "field": "timestamp", "calendar_interval": "day" },
      "aggs": {
        "by_vendor": { "terms": { "field": "vendor.keyword" } }
      }
    }
  }
}

// Degradações (sem incidentes nem manutenções)
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "event_type.keyword": "degradation" } },
        { "range": { "timestamp": { "gte": "now-24h" } } }
      ]
    }
  },
  "sort": [{ "timestamp": "desc" }]
}

// Filtrar por source (ex: somente statuscast)
GET health_vendor_status/_search
{
  "query": {
    "bool": {
      "must": [
        { "term": { "source.keyword": "statuscast" } },
        { "range": { "timestamp": { "gte": "now-24h" } } }
      ]
    }
  },
  "sort": [{ "timestamp": "desc" }]
}
```

---

## Troubleshooting

| Erro | Solução |
|---|---|
| `ELK_HOST não configurado` | Configure `ELK_HOST`, `ELK_USER`, `ELK_PASSWD` |
| `HTTP 409` | Duplicata — comportamento esperado, documento já existe |
| `HTTP 401` | Credenciais incorretas |
| `SSL certificate verify failed` | O script já desabilita verificação SSL para OpenSearch |

---

## Dashboard OpenSearch

O arquivo `opensearch-dashboard-export.ndjson` contém o dashboard completo com todas as visualizações.

### Importar/Atualizar

1. Acesse o Saved Objects Manager:
   ```
   https://seu_vpc_id.us-east-1.es.amazonaws.com/_dashboards/app/management/opensearch-dashboards/objects
   ```
2. Clique em **Import**
3. Selecione o arquivo `opensearch-dashboard-export.ndjson`
4. Marque **"Automatically overwrite all saved objects"**
5. Clique em **Import**

### Visualizações incluídas

| Painel | Descrição |
|---|---|
| Total de Ocorrências | Métrica total no período |
| Severidade Máxima (última hora) | Gauge colorido |
| Tipo de Evento | Pie chart (incident/maintenance/degradation) |
| Ocorrências por Fonte | Barras por source (statuspage, aws_health, etc) |
| Incidentes ao Longo do Tempo | Linha temporal — somente `event_type: incident` |
| Manutenções ao Longo do Tempo | Linha temporal — somente `event_type: maintenance` |
| Ocorrências por Vendor | Donut chart |
| Ocorrências por Severidade | Barras horizontais por vendor |
| Resumo por Vendor e Serviço | Tabela agregada |
| Manutenções Agendadas (Calendário) | Tabela com `scheduled_start` e `scheduled_end` |
| Ocorrências Recentes (Detalhes) | Discover com documentos individuais |

---

## Referências

Muitas das ideias aplicadas foram baseadas no repositório https://github.com/ljonesfl/down_detector

