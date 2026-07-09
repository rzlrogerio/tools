"""
StatusPageMonitor — Atlassian Statuspage (JSON API padrão).
URLs terminando em /api/v2/summary.json
"""

import base64
import datetime
import json
import urllib.request
from typing import Dict, Optional

from monitors.base import BaseMonitor


class StatusPageMonitor(BaseMonitor):
    """Monitor para Atlassian Statuspage (API JSON pública)."""

    def fetch_service_data(self, url: str, auth_token: Optional[str] = None,
                           username: Optional[str] = None,
                           password: Optional[str] = None) -> Optional[Dict]:
        try:
            headers = {}
            if auth_token:
                if not auth_token.lower().startswith('bearer '):
                    auth_token = f"Bearer {auth_token}"
                headers['Authorization'] = auth_token
            elif username and password:
                cred = base64.b64encode(f"{username}:{password}".encode()).decode('ascii')
                headers['Authorization'] = f"Basic {cred}"

            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                if resp.status == 200:
                    return json.loads(resp.read().decode("utf-8"))
                self.log(f"❌ HTTP {resp.status} ao acessar {url}")
                return None
        except Exception as e:
            self.log(f"❌ Erro ao acessar {url}: {e}")
            return None

    def check_health(self, service_name: str, status_url: str,
                     test_mode: bool = False,
                     auth_token: Optional[str] = None,
                     username: Optional[str] = None,
                     password: Optional[str] = None) -> bool:
        self.log(f"🔍 Verificando {service_name} Health...")
        vendor_name = self.extract_vendor_name(status_url)
        now = self._now_iso()

        if test_mode:
            self.log(f"🧪 MODO TESTE - Simulando falha para {service_name}")
            self.send_to_opensearch({
                "timestamp": now,
                "vendor": vendor_name,
                "source": "statuspage",
                "service": service_name,
                "status": "partial_outage",
                "severity": 2,
                "severity_label": "partial_outage",
                "description": "Simulated outage (test mode)",
                "incidents_active": 1,
                "maintenances_active": 0,
                "components_degraded": 0,
                "event_type": "test",
            })
            return True

        data = self.fetch_service_data(status_url, auth_token, username, password)
        if not data:
            self.log(f"❌ Não foi possível obter dados de {service_name}")
            return False

        page_name = data.get("page", {}).get("name", "Unknown")
        overall_indicator = data.get("status", {}).get("indicator", "none")
        overall_desc = data.get("status", {}).get("description", "Unknown")
        severity, severity_label = self.map_overall_status(overall_indicator)

        incidents = data.get("incidents", [])
        active_incidents = [inc for inc in incidents if inc.get("status") != "resolved"]

        current_date = datetime.datetime.now().strftime("%Y-%m-%d")
        maintenances = data.get("scheduled_maintenances", [])
        active_maintenances = [m for m in maintenances
                               if m.get("status") == "in_progress"
                               or m.get("scheduled_for", "").startswith(current_date)]

        components = data.get("components", [])
        degraded = [c for c in components if c.get("status") != "operational"]

        self.log(f"📊 {page_name} — {overall_indicator} ({overall_desc}) | "
                 f"incidentes: {len(active_incidents)}, manutenções: {len(active_maintenances)}, "
                 f"componentes degradados: {len(degraded)}")

        if severity == 0 and active_incidents:
            severity, severity_label = 1, "degraded"
        elif severity == 0 and active_maintenances:
            severity, severity_label = 4, "maintenance"
        elif severity == 0 and degraded:
            severity, severity_label = 1, "degraded"

        if severity > 0:
            doc = {
                "timestamp": now,
                "vendor": vendor_name,
                "source": "statuspage",
                "service": service_name,
                "page_name": page_name,
                "status": severity_label,
                "severity": severity,
                "severity_label": severity_label,
                "description": overall_desc,
                "incidents_active": len(active_incidents),
                "maintenances_active": len(active_maintenances),
                "components_degraded": len(degraded),
                "event_type": "incident" if active_incidents else ("maintenance" if active_maintenances else "degradation"),
            }

            if active_incidents:
                doc["incidents"] = [
                    {
                        "name": inc.get("name", ""),
                        "status": inc.get("status", ""),
                        "impact": inc.get("impact", ""),
                        "created_at": inc.get("created_at", ""),
                        "updated_at": inc.get("updated_at", ""),
                    }
                    for inc in active_incidents[:10]
                ]

            if degraded:
                doc["degraded_components"] = [
                    {"name": c.get("name", ""), "status": c.get("status", "")}
                    for c in degraded[:20]
                ]

            self.send_to_opensearch(doc)
            self.log(f"⚠️ {page_name} — ocorrência enviada (severity: {severity})")
        else:
            self.log(f"✅ {page_name} — operacional, nada a enviar")

        return True
