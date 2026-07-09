"""
AzureHealthMonitor — Azure Status RSS feed.
Monitora https://rssfeed.azure.status.microsoft/en-us/status/feed.
"""

import gzip
import re
import ssl
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

from monitors.base import BaseMonitor

AZURE_RSS_URL = "https://rssfeed.azure.status.microsoft/en-us/status/feed"


class AzureHealthMonitor(BaseMonitor):
    """Monitor de saúde do Azure via RSS feed."""

    def check_health(self, test_mode: bool = False) -> bool:
        self.log("🔍 Verificando Azure Health...")

        if not self._opensearch_configured():
            self.log("❌ Erro: OpenSearch não configurado.")
            return False

        now = self._now_iso()

        if test_mode:
            self.log("🧪 MODO TESTE - Simulando falhas Azure")
            self.send_to_opensearch({
                "timestamp": now, "vendor": "azure", "source": "azure_rss",
                "service": "Azure", "status": "incident",
                "severity": 2, "severity_label": "medium",
                "description": "Simulated Azure incident (test mode)",
                "event_type": "test",
            })
            return True

        try:
            req = urllib.request.Request(AZURE_RSS_URL)
            req.add_header("Accept-Encoding", "gzip, deflate")
            try:
                ctx = ssl.create_default_context()
                resp = urllib.request.urlopen(req, timeout=30, context=ctx)
            except urllib.error.URLError:
                self.log("⚠️ SSL padrão falhou, tentando sem verificação")
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                resp = urllib.request.urlopen(req, timeout=30, context=ctx)
            with resp:
                data = resp.read()
                if resp.headers.get("Content-Encoding") == "gzip" or data[:2] == b'\x1f\x8b':
                    data = gzip.decompress(data)
                try:
                    raw = data.decode("utf-8")
                except UnicodeDecodeError:
                    raw = data.decode("latin-1")
        except Exception as e:
            self.log(f"❌ Erro ao acessar Azure Health RSS: {e}")
            return False

        # Parseia RSS XML
        try:
            root = ET.fromstring(raw)
            keywords = re.compile(r'issue|outage|degraded|incident', re.IGNORECASE)

            incident_items = []
            for item in root.findall('.//item'):
                title = item.findtext('title', '')
                desc = item.findtext('description', '')
                pub_date = item.findtext('pubDate', '')
                if keywords.search(title) or keywords.search(desc):
                    incident_items.append({
                        "title": title,
                        "description": desc[:500],
                        "published": pub_date,
                    })
        except Exception:
            keyword_count = len(re.findall(r'issue|outage|degraded|incident', raw, re.IGNORECASE))
            incident_items = [{"title": f"{keyword_count} possíveis incidentes"}] if keyword_count else []

        if not incident_items:
            self.log("✅ Nenhuma falha detectada no Azure")
            return True

        self.log(f"⚠️ Detectados {len(incident_items)} possíveis incidentes no Azure")
        self.send_to_opensearch({
            "timestamp": now,
            "vendor": "azure",
            "source": "azure_rss",
            "service": "Azure",
            "status": "incident",
            "severity": 2,
            "severity_label": "medium",
            "description": f"{len(incident_items)} incidentes detectados no Azure RSS",
            "event_type": "incident",
            "incidents_active": len(incident_items),
            "incidents": incident_items[:10],
        })
        return True
