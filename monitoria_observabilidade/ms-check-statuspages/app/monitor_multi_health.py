#!/usr/bin/env python3
"""
Multi Status Page Health Monitor — OpenSearch Edition v1.0
Monitora AWS Health, Azure Health, Atlassian Statuspage, StatusCast e MoneyP/BMP.
Envia documentos JSON para OpenSearch quando há ocorrências.

Estrutura modular:
  monitors/base.py        — BaseMonitor (OpenSearch, logging, helpers)
  monitors/statuspage.py  — Atlassian Statuspage (JSON API)
  monitors/statuscast.py  — StatusCast (HTML scraping + form auth)
  monitors/moneyp.py      — MoneyP/BMP (SignalR long-polling)
  monitors/aws_health.py  — AWS Health (public events JSON)
  monitors/azure_health.py— Azure Health (RSS feed)
"""

import argparse
import os
import re
import sys

from monitors import (
    StatusPageMonitor,
    StatusCastMonitor,
    MoneyPMonitor,
    AWSHealthMonitor,
    AzureHealthMonitor,
)


# ════════════════════════════════════════════════════════════════════════
# CLI
# ════════════════════════════════════════════════════════════════════════

def show_help():
    print("""
Multi Status Page Health Monitor — OpenSearch Edition v2.0

USO:
    python3 monitor_multi_health.py [OPTIONS] [URL ...]

OPÇÕES:
    -h, --help          Mostra esta ajuda
    -t, --test          Modo teste (simula ocorrências)
    --aws               Ativa monitoramento AWS Health
    --azure             Ativa monitoramento Azure Health
    -a, --auth TOKEN    Token de autenticação para status pages protegidas
    -u, --user USER     Usuário para autenticação básica HTTP
    -p, --pass PASS     Senha para autenticação básica HTTP

VARIÁVEIS DE AMBIENTE:
    ELK_HOST            URL do OpenSearch (ex: https://opensearch.example.com:9200)
    ELK_USER            Usuário do OpenSearch
    ELK_PASSWD          Senha do OpenSearch
    ELK_INDEX           Nome do índice (padrão: health_vendor_status)

    MONITOR_AWS         Habilita AWS Health (1/true/yes)
    MONITOR_AZURE       Habilita Azure Health (1/true/yes)

    STATUSPAGE_PUBLIC   URLs públicas separadas por vírgula (suporta url|alias)
    STATUSPAGE_PRIVATE  URLs privadas separadas por vírgula (suporta url|alias)
    STATUSPAGE_AUTH_TOKEN  Token global para URLs privadas
    STATUSPAGE_ALIAS_<IDENTIFIER>  Alias amigável por URL (mesmo padrão de token/user/pass)
    STATUSPAGE_VENDOR_MAP  Mapa host/url=alias separado por vírgula
                           Ex: status.snyk.io=snyk,https://www.githubstatus.com/api/v2/summary.json=github

    STATUSCAST_URLS        URLs StatusCast adicionais (separadas por vírgula)
                           Detectado automaticamente para domínios *.status.page
    STATUSPAGE_USER_<ID>   Usuário para StatusCast (ex: STATUSPAGE_USER_VENDOR_STATUS_PAGE)
    STATUSPAGE_PASS_<ID>   Senha para StatusCast (ex: STATUSPAGE_PASS_VENDOR_STATUS_PAGE)

    MONEYP_URL             URL do SignalR/MoneyP (ex: https://status.your-signalr-vendor.com)
    MONEYP_URLS            URLs adicionais (separadas por vírgula)
    MONEYP_UPTIME_THRESHOLD  Limiar de uptime % (padrão: 98)

    AWS_HEALTH_REGIONS     Regiões AWS a monitorar (padrão: sa-east-1,us-east-1)

DOCUMENTO ENVIADO AO OPENSEARCH:
    {
      "timestamp":           "2026-03-13T10:00:00Z",
      "vendor":              "snyk | aws | azure | vendor-statuscast | vendor-signalr | ...",
      "source":              "statuspage | statuscast | moneyp_signalr | aws_health | azure_rss",
      "service":             "SNYK | EC2 | Azure | service_consulta_saldo | ...",
      "status":              "degraded | partial_outage | major_outage | maintenance | incident",
      "severity":            0-4 (0=ok, 1=degraded, 2=partial, 3=major, 4=maintenance),
      "severity_label":      "operational | degraded | partial_outage | major_outage | high | medium | low",
      "description":         "texto descritivo",
      "event_type":          "incident | maintenance | degradation | test",
      "region":              "us-east-1 (só AWS)",
      "incidents_active":    2,
      "maintenances_active": 0,
      "components_degraded": 3,
      "incidents":           [{name, status, impact, created_at}],
      "degraded_components": [{name, status}]
    }

    NOTA: Só envia documento quando há ocorrência ativa.

EXEMPLOS:
    python3 monitor_multi_health.py --aws --azure URL1 URL2
    python3 monitor_multi_health.py --aws --azure --test
    MONITOR_AWS=true MONITOR_AZURE=true python3 monitor_multi_health.py
""")


def _validate_url(url: str, statuscast: StatusCastMonitor, moneyp: MoneyPMonitor) -> bool:
    """Valida formato da URL conforme o tipo de monitor."""
    if statuscast.is_statuscast_url(url):
        return bool(re.match(r'^https?://', url))
    if moneyp.is_moneyp_url(url):
        return bool(re.match(r'^https?://', url))
    return bool(re.match(r'^https?://.*\.json$', url))


def main():
    parser = argparse.ArgumentParser(description="Health Monitor — OpenSearch", add_help=False)
    parser.add_argument("-h", "--help", action="store_true")
    parser.add_argument("-t", "--test", action="store_true")
    parser.add_argument("-a", "--auth", type=str)
    parser.add_argument("-u", "--user", type=str)
    parser.add_argument("-p", "--pass", type=str, dest="password")
    parser.add_argument("--aws", action="store_true")
    parser.add_argument("--azure", action="store_true")
    parser.add_argument("urls", nargs="*")

    args = parser.parse_args()

    if args.help:
        show_help()
        sys.exit(0)

    if args.user and not args.password:
        print("❌ --user requer --pass")
        sys.exit(1)
    if args.password and not args.user:
        print("❌ --pass requer --user")
        sys.exit(1)

    # Instancia os monitores (compartilham configuração OpenSearch via env)
    sp_monitor = StatusPageMonitor()
    sc_monitor = StatusCastMonitor()
    mp_monitor = MoneyPMonitor()
    aws_monitor = AWSHealthMonitor()
    azure_monitor = AzureHealthMonitor()

    # Usa sp_monitor como "base" para helpers de URL/alias
    base = sp_monitor

    # ── URLs via env vars ───────────────────────────────────────────────
    statuspage_public = os.getenv("STATUSPAGE_PUBLIC", "").strip()
    statuspage_private = os.getenv("STATUSPAGE_PRIVATE", "").strip()
    statuspage_auth_token = os.getenv("STATUSPAGE_AUTH_TOKEN", "").strip()

    urls_with_auth = []

    if statuspage_public:
        public_entries = [u.strip() for u in statuspage_public.split(",") if u.strip()]
        print(f"📋 URLs públicas obtidas (STATUSPAGE_PUBLIC): {len(public_entries)}")
        for entry in public_entries:
            u, alias = base.parse_statuspage_entry(entry)
            if not u:
                continue
            base.register_runtime_alias(u, alias)
            urls_with_auth.append((u, None, None, None))

    if statuspage_private:
        private_entries = [u.strip() for u in statuspage_private.split(",") if u.strip()]
        print(f"🔐 URLs privadas obtidas (STATUSPAGE_PRIVATE): {len(private_entries)}")
        for entry in private_entries:
            u, alias = base.parse_statuspage_entry(entry)
            if not u:
                continue
            base.register_runtime_alias(u, alias)
            t, usr, pwd = base.get_credentials_for_url(u)
            if t or (usr and pwd):
                urls_with_auth.append((u, t, usr, pwd))
            elif statuspage_auth_token:
                urls_with_auth.append((u, statuspage_auth_token, None, None))
            elif args.auth:
                urls_with_auth.append((u, args.auth, None, None))
            else:
                urls_with_auth.append((u, None, None, None))

    # MoneyP via env var
    moneyp_url_raw = os.getenv("MONEYP_URL", "").strip()
    if moneyp_url_raw:
        u, alias = base.parse_statuspage_entry(moneyp_url_raw)
        if u:
            base.register_runtime_alias(u, alias)
            urls_with_auth.append((u, None, None, None))

    if not urls_with_auth and args.urls:
        for u in args.urls:
            url, alias = base.parse_statuspage_entry(u)
            if not url:
                continue
            base.register_runtime_alias(url, alias)
            urls_with_auth.append((url, args.auth, args.user, args.password))

    # ── Monitores nativos ───────────────────────────────────────────────
    aws_enabled = args.aws or os.getenv("MONITOR_AWS", "").lower() in ("1", "true", "yes")
    azure_enabled = args.azure or os.getenv("MONITOR_AZURE", "").lower() in ("1", "true", "yes")

    if aws_enabled:
        aws_monitor.log("🔍 AWS Health Monitor habilitado")
        aws_monitor.check_health(test_mode=args.test)

    if azure_enabled:
        azure_monitor.log("🔍 Azure Health Monitor habilitado")
        azure_monitor.check_health(test_mode=args.test)

    if not urls_with_auth and (aws_enabled or azure_enabled):
        print("\n✅ Monitoramento concluído")
        sys.exit(0)

    if not urls_with_auth and not aws_enabled and not azure_enabled:
        print("❌ Nenhuma URL fornecida e nenhum monitor nativo habilitado")
        print("Use --help para ver as opções.")
        sys.exit(1)

    # ── Status Pages ────────────────────────────────────────────────────
    print(f"\n🚀 Iniciando Multi Health Monitor v2.0 (OpenSearch)")
    if args.test:
        print("🧪 MODO TESTE ATIVADO")

    success_count = 0
    total_count = len(urls_with_auth)

    # Propaga aliases para todos os monitors
    for mon in (sc_monitor, mp_monitor):
        mon.runtime_alias_by_identifier = base.runtime_alias_by_identifier

    for url, token, user, passwd in urls_with_auth:
        if not _validate_url(url, sc_monitor, mp_monitor):
            print(f"❌ URL inválida: {url}")
            continue

        svc = base.extract_service_name(url)

        if sc_monitor.is_statuscast_url(url):
            # StatusCast: usa login por formulário (user/pass obrigatórios)
            sc_user = user
            sc_pass = passwd
            if not sc_user or not sc_pass:
                _, sc_user, sc_pass = base.get_credentials_for_url(url)
            if sc_monitor.check_health(svc, url, args.test, sc_user, sc_pass):
                success_count += 1
            # Buscar manutenções agendadas (calendário) — próximos 7 dias
            sc_monitor.fetch_scheduled_maintenances(svc, url, sc_user, sc_pass, days_ahead=7)

        elif mp_monitor.is_moneyp_url(url):
            # MoneyP/BMP: SignalR long-polling
            if mp_monitor.check_health(svc, url, args.test):
                success_count += 1

        else:
            # Atlassian Statuspage (JSON API padrão)
            if sp_monitor.check_health(svc, url, args.test, token, user, passwd):
                success_count += 1

    print(f"\n✅ Monitoramento concluído: {success_count}/{total_count} verificações bem-sucedidas")
    sys.exit(0 if success_count == total_count else 1)


if __name__ == "__main__":
    main()
