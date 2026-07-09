"""
AWSHealthMonitor — AWS Health public events.
Monitora https://health.aws.amazon.com/public/currentevents.
Filtra por regiões via env AWS_HEALTH_REGIONS (padrão: sa-east-1,us-east-1).
"""

import gzip
import json
import os
import re
import ssl
import urllib.request
from typing import Tuple

from monitors.base import BaseMonitor

AWS_HEALTH_URL = "https://health.aws.amazon.com/public/currentevents"


class AWSHealthMonitor(BaseMonitor):
    """Monitor de eventos públicos do AWS Health."""

    def _clean_service_name(self, service: str) -> str:
        return re.sub(r'_+', '_', re.sub(r'[^a-z0-9]', '_', service.lower())).strip('_')

    def _aws_severity_label(self, status: str) -> Tuple[str, int]:
        if status in ("critical", "major"):
            return "high", 3
        if status in ("minor", "informational"):
            return "low", 1
        return "medium", 2

    def check_health(self, test_mode: bool = False) -> bool:
        self.log("🔍 Verificando AWS Health StatusPage...")

        if not self._opensearch_configured():
            self.log("❌ Erro: OpenSearch não configurado.")
            return False

        now = self._now_iso()

        if test_mode:
            self.log("🧪 MODO TESTE - Simulando falhas AWS")
            self.send_to_opensearch({
                "timestamp": now, "vendor": "aws", "source": "aws_health",
                "service": "EC2", "region": "us-east-1",
                "status": "active", "severity": 3, "severity_label": "high",
                "description": "Simulated EC2 outage (test mode)",
                "event_type": "test",
            })
            return True

        try:
            req = urllib.request.Request(AWS_HEALTH_URL)
            req.add_header("Accept-Encoding", "gzip, deflate")
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
                data = resp.read()
                if resp.headers.get("Content-Encoding") == "gzip" or data[:2] == b'\x1f\x8b':
                    data = gzip.decompress(data)
                if data[:2] in (b'\xfe\xff', b'\xff\xfe'):
                    raw = data.decode("utf-16")
                else:
                    try:
                        raw = data.decode("utf-8")
                    except UnicodeDecodeError:
                        raw = data.decode("latin-1")
                events = json.loads(raw)
        except Exception as e:
            self.log(f"❌ Erro ao acessar AWS Health: {e}")
            return False

        active = [ev for ev in events if ev.get("status") != "resolved"] if isinstance(events, list) else []

        # Filtrar por regiões de interesse
        aws_regions_raw = os.getenv("AWS_HEALTH_REGIONS", "sa-east-1,us-east-1").strip()
        allowed_regions = {r.strip().lower() for r in aws_regions_raw.split(",") if r.strip()}
        if allowed_regions:
            active = [
                ev for ev in active
                if ev.get("region_name", ev.get("region", "global")).lower() in allowed_regions
            ]
            self.log(f"📌 Filtro de regiões AWS: {', '.join(sorted(allowed_regions))}")

        if not active:
            self.log("✅ Nenhuma falha detectada na AWS (regiões filtradas)")
            return True

        for ev in active:
            service = ev.get("service_name", ev.get("service", "unknown"))
            region = ev.get("region_name", ev.get("region", "global"))
            status_val = ev.get("status", "unknown")
            summary = ev.get("summary", "")
            sev_label, sev_num = self._aws_severity_label(status_val)

            self.send_to_opensearch({
                "timestamp": now,
                "vendor": "aws",
                "source": "aws_health",
                "service": self._clean_service_name(service),
                "service_display": service,
                "region": region,
                "status": status_val,
                "severity": sev_num,
                "severity_label": sev_label,
                "description": summary[:500] if summary else f"AWS {service} issue in {region}",
                "event_type": "incident",
            })
            self.log(f"🚨 AWS falha: {service} ({region}) — {status_val}")

        self.log(f"🚨 Total de falhas AWS: {len(active)}")
        return True
