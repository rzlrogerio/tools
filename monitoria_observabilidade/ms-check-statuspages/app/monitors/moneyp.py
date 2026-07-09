"""
MoneyPMonitor — BMP/MoneyP Status Page (SignalR long-polling).
Monitora uptime de serviços FGTS/CEF via hub SignalR.
"""

import json
import os
import urllib.request
import urllib.parse
from typing import Dict, List, Optional

from monitors.base import BaseMonitor

# Threshold padrão: se uptime < 98%, reporta degradação
DEFAULT_UPTIME_THRESHOLD = 98.0


class MoneyPMonitor(BaseMonitor):
    """Monitor para BMP/MoneyP Status Page via SignalR long-polling."""

    SERVICES = {
        "ReceivedUptimePercent": {
            "args_map": ["consulta_saldo", "averbacao", "autenticacao"],
        },
    }

    DAILY_TARGETS = [
        "ReceivedUpTimeConsultaSaldoDailyBarChart",
        "ReceivedUpTimeAverbacaoDesaverbacaoDailyBarChart",
        "ReceivedUpTimeAuthDailyBarChart",
    ]

    SERVICE_LABELS = {
        "ReceivedUpTimeConsultaSaldoDailyBarChart": "consulta_saldo",
        "ReceivedUpTimeAverbacaoDesaverbacaoDailyBarChart": "averbacao_desaverbacao",
        "ReceivedUpTimeAuthDailyBarChart": "autenticacao",
    }

    def is_moneyp_url(self, url: str) -> bool:
        hostname = (urllib.parse.urlparse(url).hostname or "").lower()
        if "moneyp" in hostname or "bmp" in hostname:
            return True
        moneyp_urls = os.getenv("MONEYP_URLS", "").strip()
        if moneyp_urls:
            for item in moneyp_urls.split(","):
                h = self._extract_hostname(item)
                if h and h == hostname:
                    return True
        return False

    def _signalr_connect(self, base_url: str) -> Optional[Dict]:
        """Conecta via SignalR long-polling e retorna mensagens recebidas."""
        base = base_url.rstrip('/')
        hub_url = f"{base}/Hubs/DashboardHub"

        try:
            # 1. Negotiate
            neg_req = urllib.request.Request(
                hub_url + "/negotiate?negotiateVersion=1",
                method="POST",
                headers={"Content-Type": "application/json"},
                data=b"",
            )
            with urllib.request.urlopen(neg_req, timeout=15) as resp:
                neg = json.loads(resp.read())
            conn_token = neg["connectionToken"]
            poll_url = f"{hub_url}?id={urllib.parse.quote(conn_token)}"

            # 2. Handshake
            hs_data = b'{"protocol":"json","version":1}\x1e'
            hs_req = urllib.request.Request(
                poll_url, method="POST", data=hs_data,
                headers={"Content-Type": "text/plain;charset=UTF-8"},
            )
            with urllib.request.urlopen(hs_req, timeout=15) as resp:
                resp.read()

            # 3. GET handshake ack
            with urllib.request.urlopen(urllib.request.Request(poll_url), timeout=15) as resp:
                resp.read()

            # 4. Invoke Initializing
            invoke_data = b'{"type":1,"target":"Initializing","arguments":[]}\x1e'
            inv_req = urllib.request.Request(
                poll_url, method="POST", data=invoke_data,
                headers={"Content-Type": "text/plain;charset=UTF-8"},
            )
            with urllib.request.urlopen(inv_req, timeout=15) as resp:
                resp.read()

            # 5. Receive data (first long-poll)
            messages = {}
            for _ in range(3):
                with urllib.request.urlopen(urllib.request.Request(poll_url), timeout=30) as resp:
                    raw = resp.read().decode("utf-8", errors="replace")
                if not raw.strip():
                    continue
                for part in raw.split("\x1e"):
                    part = part.strip()
                    if not part:
                        continue
                    try:
                        msg = json.loads(part)
                        target = msg.get("target", "")
                        if target:
                            messages[target] = msg.get("arguments", [])
                    except json.JSONDecodeError:
                        pass
                # Se já temos os dados de percent, podemos parar
                if "ReceivedUptimePercent" in messages:
                    break

            # 6. Delete connection (cleanup)
            try:
                del_req = urllib.request.Request(poll_url, method="DELETE")
                urllib.request.urlopen(del_req, timeout=5)
            except Exception:
                pass

            return messages

        except Exception as e:
            self.log(f"❌ MoneyP: Erro na conexão SignalR: {e}")
            return None

    def _analyze_daily_data(self, daily_data: List[Dict]) -> Dict:
        """Analisa dados diários e retorna status do dia atual."""
        if not daily_data:
            return {"is_up": True, "downtime_percent": 0, "downtime_hours": 0, "missing": True}

        today_entry = daily_data[-1] if daily_data else None
        if not today_entry:
            return {"is_up": True, "downtime_percent": 0, "downtime_hours": 0, "missing": True}

        return {
            "is_up": today_entry.get("isUp", True),
            "downtime_percent": today_entry.get("downtimePercent", 0),
            "downtime_hours": today_entry.get("downtimeHours", 0),
            "missing": today_entry.get("isMissingInfo", False),
            "date": today_entry.get("statusDate", ""),
        }

    def check_health(self, service_name: str, status_url: str,
                     test_mode: bool = False, **kwargs) -> bool:
        self.log(f"🔍 Verificando {service_name} Health (MoneyP/SignalR)...")
        vendor_name = self.extract_vendor_name(status_url)
        now = self._now_iso()

        if test_mode:
            self.log(f"🧪 MODO TESTE — Simulando falha MoneyP para {service_name}")
            self.send_to_opensearch({
                "timestamp": now,
                "vendor": vendor_name,
                "source": "moneyp_signalr",
                "service": service_name,
                "status": "degraded",
                "severity": 1,
                "severity_label": "degraded",
                "description": "Simulated degradation (test mode)",
                "incidents_active": 0,
                "maintenances_active": 0,
                "components_degraded": 1,
                "event_type": "test",
            })
            return True

        messages = self._signalr_connect(status_url)
        if messages is None:
            return False

        threshold = float(os.getenv("MONEYP_UPTIME_THRESHOLD", str(DEFAULT_UPTIME_THRESHOLD)))

        # Analisa uptime percentual geral
        percent_args = messages.get("ReceivedUptimePercent", [])
        uptime_values = {}
        labels = ["consulta_saldo", "averbacao", "autenticacao"]
        for i, label in enumerate(labels):
            if i < len(percent_args):
                uptime_values[label] = float(percent_args[i])

        self.log(f"📊 {service_name} (MoneyP) — Uptimes: " +
                 ", ".join(f"{k}={v}%" for k, v in uptime_values.items()))

        # Analisa dados diários
        daily_status = {}
        for target in self.DAILY_TARGETS:
            svc_label = self.SERVICE_LABELS.get(target, target)
            args = messages.get(target, [])
            if args and isinstance(args[0], list):
                daily_status[svc_label] = self._analyze_daily_data(args[0])

        # Determina severidade
        degraded_services = []
        for label, uptime in uptime_values.items():
            if uptime < threshold:
                degraded_services.append({"name": f"fgts_{label}", "status": f"uptime_{uptime}%"})

        for label, status in daily_status.items():
            if not status.get("is_up", True) and not status.get("missing", False):
                if not any(d["name"] == f"fgts_{label}" for d in degraded_services):
                    degraded_services.append({
                        "name": f"fgts_{label}",
                        "status": f"down (downtime {status['downtime_percent']}%)",
                    })

        if degraded_services:
            worst_uptime = min(uptime_values.values()) if uptime_values else 100
            if worst_uptime < 50:
                severity, severity_label = 3, "major_outage"
            elif worst_uptime < 80:
                severity, severity_label = 2, "partial_outage"
            else:
                severity, severity_label = 1, "degraded"

            doc = {
                "timestamp": now,
                "vendor": vendor_name,
                "source": "moneyp_signalr",
                "service": service_name,
                "page_name": "BMP Status Page",
                "status": severity_label,
                "severity": severity,
                "severity_label": severity_label,
                "description": f"Uptime degradado: " +
                               ", ".join(f"{k}={v}%" for k, v in uptime_values.items()),
                "incidents_active": 0,
                "maintenances_active": 0,
                "components_degraded": len(degraded_services),
                "event_type": "degradation",
                "degraded_components": degraded_services,
                "uptime_values": uptime_values,
            }
            self.send_to_opensearch(doc)
            self.log(f"⚠️ {service_name} (MoneyP) — ocorrência enviada (severity: {severity})")
        else:
            self.log(f"✅ {service_name} (MoneyP) — operacional "
                     f"(todos acima de {threshold}%), nada a enviar")

        return True
