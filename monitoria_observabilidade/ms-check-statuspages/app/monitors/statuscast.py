"""
StatusCastMonitor — StatusCast (ex: generic-vendor.status.page).
Autenticação via formulário + scraping HTML.
"""

import html as html_mod
import http.cookiejar
import json
import os
import re
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from monitors.base import BaseMonitor


class StatusCastMonitor(BaseMonitor):
    """Monitor para StatusCast — login via formulário e scraping HTML."""

    def is_statuscast_url(self, url: str) -> bool:
        if url.rstrip('/').endswith('.json'):
            return False
        hostname = (urllib.parse.urlparse(url).hostname or "").lower()
        if hostname.endswith('.status.page'):
            return True
        sc_urls = os.getenv("STATUSCAST_URLS", "").strip()
        if sc_urls:
            for item in sc_urls.split(","):
                h = self._extract_hostname(item)
                if h and h == hostname:
                    return True
        return False

    def _login(self, base_url: str, username: str, password: str) -> Optional[urllib.request.OpenerDirector]:
        base = base_url.rstrip('/')
        cj = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(cj),
            urllib.request.HTTPRedirectHandler,
        )
        try:
            req = urllib.request.Request(base + "/")
            resp = opener.open(req, timeout=30)
            html_text = resp.read().decode("utf-8", errors="replace")

            token_match = re.search(
                r'name="__RequestVerificationToken"[^>]*value="([^"]+)"', html_text
            )
            if not token_match:
                self.log("❌ StatusCast: CSRF token não encontrado na página de login")
                return None
            csrf_token = token_match.group(1)

            form_data = urllib.parse.urlencode({
                "LoginVM.Email": username,
                "LoginVM.Password": password,
                "LoginVM.Activate": "False",
                "LoginVM.InviteKey": "",
                "LoginVM.ReturnUrl": "",
                "__RequestVerificationToken": csrf_token,
            }).encode("utf-8")

            login_req = urllib.request.Request(
                base + "/login?handler=login",
                data=form_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                method="POST",
            )
            resp2 = opener.open(login_req, timeout=30)
            resp2.read()

            auth_cookies = [c for c in cj if "Identity" in c.name or "AspNetCore" in c.name]
            if not auth_cookies:
                self.log("❌ StatusCast: Login falhou — cookie de autenticação não recebido")
                return None

            self.log("✅ StatusCast: Login bem-sucedido")
            return opener
        except Exception as e:
            self.log(f"❌ StatusCast: Erro no login: {e}")
            return None

    def _parse_html(self, html_text: str) -> Dict:
        result = {
            "overall_status": "unknown",
            "overall_indicator": "none",
            "components": [],
            "active_incidents": [],
            "active_maintenances": [],
        }

        # ── Seção "Current Status" ──────────────────────────────────────
        status_section = html_text
        parts = html_text.split('Current Status')
        if len(parts) > 1:
            after = parts[1]
            if 'Current Incidents' in after:
                status_section = after.split('Current Incidents')[0]
            else:
                status_section = after[:3000]

        overall_match = re.search(
            r'current-status-comp-status-text[^>]*>([^<]+)', status_section
        )
        if overall_match:
            result["overall_status"] = html_mod.unescape(overall_match.group(1).strip())

        overall_text = result["overall_status"].lower()
        if "normal" in overall_text or "operational" in overall_text:
            result["overall_indicator"] = "none"
        elif "degraded" in overall_text or "performance" in overall_text:
            result["overall_indicator"] = "minor"
        elif "disruption" in overall_text or "outage" in overall_text:
            result["overall_indicator"] = "major"
        elif "maintenance" in overall_text:
            result["overall_indicator"] = "maintenance"
        else:
            result["overall_indicator"] = "minor"

        comp_statuses = re.findall(
            r'<i\s+class="fa\s+component-(available|degraded|unavailable|maintenance)"\s*>',
            status_section,
        )
        for cs in comp_statuses:
            result["components"].append({"name": cs, "status": cs})

        degraded = [c for c in result["components"] if c["status"] != "available"]

        if degraded and result["overall_indicator"] == "none":
            has_unavailable = any(c["status"] == "unavailable" for c in degraded)
            has_maintenance = any(c["status"] == "maintenance" for c in degraded)
            if has_unavailable:
                result["overall_indicator"] = "major"
            elif has_maintenance:
                result["overall_indicator"] = "maintenance"
            else:
                result["overall_indicator"] = "minor"

        # ── Seção "Current Incidents" ─────────────────────────────────────
        incidents_section = ""
        inc_parts = html_text.split('Current Incidents')
        if len(inc_parts) > 1:
            after_inc = inc_parts[1]
            # Limitar até a próxima seção conhecida
            for boundary in ('Past Incidents', 'Scheduled Maintenance', 'Incident History'):
                if boundary in after_inc:
                    after_inc = after_inc.split(boundary)[0]
                    break
            incidents_section = after_inc[:5000]

        incident_pattern = re.compile(
            r'href="/incident/(\d+)"[^>]*>\s*(.*?)\s*</a>', re.DOTALL
        )
        seen_ids = set()
        for m in incident_pattern.finditer(incidents_section):
            inc_id = m.group(1)
            if inc_id in seen_ids:
                continue
            seen_ids.add(inc_id)
            raw_name = re.sub(r'<[^>]+>', '', m.group(2)).strip()
            name = html_mod.unescape(raw_name) if raw_name else f"Incident #{inc_id}"

            lower_name = name.lower()
            if any(kw in lower_name for kw in ("manutenção", "manuten", "maintenance", "scheduled")):
                result["active_maintenances"].append({
                    "name": name, "status": "in_progress", "id": inc_id,
                })
            else:
                result["active_incidents"].append({
                    "name": name, "status": "investigating", "impact": "unknown", "id": inc_id,
                })

        return result

    def check_health(self, service_name: str, status_url: str,
                     test_mode: bool = False,
                     username: Optional[str] = None,
                     password: Optional[str] = None) -> bool:
        self.log(f"🔍 Verificando {service_name} Health (StatusCast)...")
        vendor_name = self.extract_vendor_name(status_url)
        now = self._now_iso()

        if test_mode:
            self.log(f"🧪 MODO TESTE — Simulando falha StatusCast para {service_name}")
            self.send_to_opensearch({
                "timestamp": now,
                "vendor": vendor_name,
                "source": "statuscast",
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

        if not username or not password:
            self.log(f"❌ StatusCast requer credenciais (user/pass) para {service_name}")
            return False

        base_url = status_url.rstrip('/')
        opener = self._login(base_url, username, password)
        if not opener:
            return False

        try:
            req = urllib.request.Request(base_url + "/")
            resp = opener.open(req, timeout=30)
            html_text = resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            self.log(f"❌ Erro ao acessar StatusCast {service_name}: {e}")
            return False

        data = self._parse_html(html_text)

        overall_indicator = data["overall_indicator"]
        overall_desc = data["overall_status"]
        severity, severity_label = self.map_overall_status(overall_indicator)

        active_incidents = data["active_incidents"]
        active_maintenances = data["active_maintenances"]
        degraded = [c for c in data["components"]
                    if c["status"] not in ("available", "informational")]

        self.log(f"📊 {service_name} (StatusCast) — {overall_indicator} ({overall_desc}) | "
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
                "source": "statuscast",
                "service": service_name,
                "page_name": service_name,
                "status": severity_label,
                "severity": severity,
                "severity_label": severity_label,
                "description": overall_desc,
                "incidents_active": len(active_incidents),
                "maintenances_active": len(active_maintenances),
                "components_degraded": len(degraded),
                "event_type": (
                    "incident" if active_incidents
                    else ("maintenance" if active_maintenances
                          else "degradation")
                ),
            }

            if active_incidents:
                doc["incidents"] = [
                    {"name": inc.get("name", ""), "status": inc.get("status", ""),
                     "impact": inc.get("impact", ""), "id": inc.get("id", "")}
                    for inc in active_incidents[:10]
                ]

            if degraded:
                doc["degraded_components"] = [
                    {"name": c.get("name", ""), "status": c.get("status", "")}
                    for c in degraded[:20]
                ]

            self.send_to_opensearch(doc)
            self.log(f"⚠️ {service_name} (StatusCast) — ocorrência enviada (severity: {severity})")
        else:
            self.log(f"✅ {service_name} (StatusCast) — operacional, nada a enviar")

        return True

    # ── Calendar — manutenções agendadas ────────────────────────────────

    def _get_calendar_widget_id(self, html_text: str) -> Optional[str]:
        """Extrai o widgetId do FullCalendar da página."""
        match = re.search(r'class="fullcalendar"\s+data-options="([^"]+)"', html_text)
        if not match:
            return None
        decoded = html_mod.unescape(match.group(1))
        try:
            opts = json.loads(decoded)
            return opts.get("Id")
        except (json.JSONDecodeError, KeyError):
            return None

    def fetch_scheduled_maintenances(
        self, service_name: str, status_url: str,
        username: Optional[str] = None, password: Optional[str] = None,
        days_ahead: int = 7,
    ) -> List[Dict]:
        """
        Obtém manutenções agendadas da API de calendário do StatusCast
        para hoje + days_ahead dias e envia cada evento ao OpenSearch.
        """
        self.log(f"📅 Buscando manutenções agendadas de {service_name} (próximos {days_ahead} dias)...")
        vendor_name = self.extract_vendor_name(status_url)
        base_url = status_url.rstrip('/')

        if not username or not password:
            self.log(f"❌ StatusCast requer credenciais para calendar de {service_name}")
            return []

        opener = self._login(base_url, username, password)
        if not opener:
            return []

        # Obter widget ID da página principal
        try:
            req = urllib.request.Request(base_url + "/")
            resp = opener.open(req, timeout=30)
            html_text = resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            self.log(f"❌ Erro ao acessar {service_name} para obter calendar ID: {e}")
            return []

        widget_id = self._get_calendar_widget_id(html_text)
        if not widget_id:
            self.log(f"⚠️ Widget de calendário não encontrado em {service_name}")
            return []

        # Chamar API de eventos do calendário
        now = datetime.now(timezone.utc)
        start = now.strftime("%Y-%m-%d")
        end = (now + timedelta(days=days_ahead)).strftime("%Y-%m-%d")
        cal_url = f"{base_url}/statuspages/calendarevents?id={widget_id}&start={start}&end={end}"

        try:
            req = urllib.request.Request(cal_url)
            resp = opener.open(req, timeout=30)
            content = resp.read().decode("utf-8", errors="replace")
            events = json.loads(content)
        except Exception as e:
            self.log(f"❌ Erro ao obter calendário de {service_name}: {e}")
            return []

        self.log(f"📅 {service_name} — {len(events)} evento(s) agendado(s) nos próximos {days_ahead} dias")

        sent_events = []
        for ev in events:
            title = ev.get("title", "Sem título")
            ev_start = ev.get("start", "")
            ev_end = ev.get("end", "")
            incident_id = ev.get("extendedProps", {}).get("incidentId", "")
            ev_url = ev.get("url", "")

            doc = {
                "timestamp": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "vendor": vendor_name,
                "source": "statuscast",
                "service": service_name,
                "page_name": service_name,
                "status": "scheduled_maintenance",
                "severity": 4,
                "severity_label": "maintenance",
                "description": title,
                "event_type": "scheduled_maintenance",
                "scheduled_start": ev_start,
                "scheduled_end": ev_end,
                "incident_id": str(incident_id),
                "incident_url": ev_url,
                "incidents_active": 0,
                "maintenances_active": 1,
                "components_degraded": 0,
            }

            self.send_to_opensearch(doc)
            sent_events.append(doc)
            self.log(f"  📅 {title} | {ev_start} → {ev_end}")

        return sent_events
