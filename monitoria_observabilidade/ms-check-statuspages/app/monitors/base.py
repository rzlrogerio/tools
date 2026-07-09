"""
BaseMonitor — Classe base com OpenSearch sender, logging e helpers de extração.
"""

import base64
import datetime
import hashlib
import json
import os
import re
import ssl
import urllib.request
import urllib.parse
import urllib.error
from typing import Dict, Tuple, Optional


class BaseMonitor:
    """Monitor base — logging, OpenSearch e helpers compartilhados."""

    ELK_HOST = os.getenv("ELK_HOST", "")
    ELK_USER = os.getenv("ELK_USER", "")
    ELK_PASSWD = os.getenv("ELK_PASSWD", "")
    ELK_INDEX = os.getenv("ELK_INDEX", "health_vendor_status")
    LOG_FILE = "/tmp/multi_health_monitor.log"

    def __init__(self):
        self.success_count = 0
        self.total_count = 0
        self.credentials_cache = {}
        self.runtime_alias_by_identifier = {}

    # ── Logging ─────────────────────────────────────────────────────────

    def log(self, message: str) -> None:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        formatted = f"[{timestamp}] {message}"
        print(formatted)
        try:
            with open(self.LOG_FILE, "a", encoding="utf-8") as f:
                f.write(formatted + "\n")
        except IOError:
            pass

    # ── OpenSearch sender ───────────────────────────────────────────────

    def _opensearch_configured(self) -> bool:
        return bool(self.ELK_HOST and self.ELK_USER and self.ELK_PASSWD)

    def send_to_opensearch(self, document: Dict) -> bool:
        """
        Envia documento JSON para OpenSearch via PUT (idempotente).
        Usa MD5 de campos-chave como _id para evitar duplicatas.
        """
        if not self._opensearch_configured():
            self.log("❌ Erro: ELK_HOST, ELK_USER ou ELK_PASSWD não configurados.")
            return False

        id_source = (
            f"{document.get('vendor', '')}"
            f"{document.get('service', '')}"
            f"{document.get('region', '')}"
            f"{document.get('event_type', '')}"
            f"{document.get('timestamp', '')}"
        )
        doc_id = hashlib.md5(id_source.encode()).hexdigest()

        url = f"{self.ELK_HOST.rstrip('/')}/{self.ELK_INDEX}/_doc/{doc_id}?op_type=create"

        credentials = f"{self.ELK_USER}:{self.ELK_PASSWD}"
        auth_header = f"Basic {base64.b64encode(credentials.encode()).decode('ascii')}"

        headers = {
            "Content-Type": "application/json",
            "Authorization": auth_header,
        }

        body = json.dumps(document).encode("utf-8")

        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            req = urllib.request.Request(url, data=body, headers=headers, method="PUT")
            with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
                if resp.status in (200, 201):
                    self.log(f"✅ Documento enviado: {document.get('vendor')}/{document.get('service')} "
                             f"[{document.get('status')}]")
                    return True
                else:
                    self.log(f"❌ Erro ao enviar documento. HTTP: {resp.status}")
                    return False
        except urllib.error.HTTPError as e:
            if e.code == 409:
                self.log(f"⏭️ Documento já existe (duplicata): {doc_id[:12]}...")
                return True
            self.log(f"❌ Erro HTTP ao enviar documento: {e.code} {e.reason}")
            return False
        except Exception as e:
            self.log(f"❌ Erro ao enviar documento ao OpenSearch: {e}")
            return False

    # ── Helpers ─────────────────────────────────────────────────────────

    def _now_iso(self) -> str:
        return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    def extract_url_identifier(self, url: str) -> str:
        identifier = re.sub(r'^https?://', '', url)
        identifier = re.sub(r'/api/.*$', '', identifier)
        identifier = identifier.rstrip('/')
        identifier = identifier.replace('.', '_').replace('-', '_')
        return identifier.lower()

    def get_credentials_for_url(self, url: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        identifier = self.extract_url_identifier(url)
        token = os.getenv(f"STATUSPAGE_TOKEN_{identifier.upper()}", "").strip() or None
        username = os.getenv(f"STATUSPAGE_USER_{identifier.upper()}", "").strip() or None
        password = os.getenv(f"STATUSPAGE_PASS_{identifier.upper()}", "").strip() or None
        return token, username, password

    def parse_statuspage_entry(self, entry: str) -> Tuple[str, Optional[str]]:
        raw = entry.strip()
        if not raw:
            return "", None
        if "|" not in raw:
            return raw, None
        url, alias = raw.split("|", 1)
        clean_url = url.strip()
        clean_alias = alias.strip()
        return clean_url, (self._sanitize_alias(clean_alias) if clean_alias else None)

    def register_runtime_alias(self, url: str, alias: Optional[str]) -> None:
        if not alias:
            return
        identifier = self.extract_url_identifier(url)
        self.runtime_alias_by_identifier[identifier] = self._sanitize_alias(alias)

    def _sanitize_alias(self, value: str) -> str:
        return re.sub(r'[^a-zA-Z0-9]', '_', value).strip('_').lower() or 'vendor'

    def _extract_hostname(self, value: str) -> str:
        raw = value.strip().lower()
        if not raw:
            return ""
        if raw.startswith("http://") or raw.startswith("https://"):
            return (urllib.parse.urlparse(raw).hostname or "").lower()
        return raw.split('/')[0]

    def _vendor_alias_from_map_env(self, hostname: str) -> Optional[str]:
        mapping_raw = os.getenv("STATUSPAGE_VENDOR_MAP", "").strip()
        if not mapping_raw:
            return None
        for item in mapping_raw.split(','):
            part = item.strip()
            if not part or '=' not in part:
                continue
            host_or_url, alias = part.split('=', 1)
            env_host = self._extract_hostname(host_or_url)
            if env_host and env_host == hostname and alias.strip():
                return self._sanitize_alias(alias)
        return None

    def get_vendor_alias_for_url(self, url: str) -> Optional[str]:
        identifier = self.extract_url_identifier(url)
        runtime_alias = self.runtime_alias_by_identifier.get(identifier)
        if runtime_alias:
            return runtime_alias
        alias = os.getenv(f"STATUSPAGE_ALIAS_{identifier.upper()}", "").strip()
        if alias:
            return self._sanitize_alias(alias)
        hostname = (urllib.parse.urlparse(url).hostname or "").lower()
        return self._vendor_alias_from_map_env(hostname)

    def extract_service_name(self, url: str) -> str:
        match = re.search(r'https?://status\.([^.]+)\.', url)
        if match:
            return match.group(1)
        try:
            hostname = urllib.parse.urlparse(url).hostname or ""
            return re.sub(r'[^a-zA-Z0-9]', '_', hostname)
        except Exception:
            return "unknown"

    def extract_vendor_name(self, url: str) -> str:
        try:
            hostname = urllib.parse.urlparse(url).hostname or ""
            explicit_alias = self.get_vendor_alias_for_url(url)
            if explicit_alias:
                return explicit_alias
            m = re.search(r'status\.([^.]+)\.', hostname)
            if m:
                return m.group(1).lower()
            m = re.search(r'([^.]+)\.statuspage\.io', hostname)
            if m:
                return m.group(1).lower()
            return re.sub(r'[^a-zA-Z0-9]', '_', hostname.split('.')[0]).lower() or 'vendor'
        except Exception:
            return "vendor"

    def map_overall_status(self, indicator: str) -> Tuple[int, str]:
        mapping = {
            "none": (0, "operational"),
            "operational": (0, "operational"),
            "minor": (1, "degraded"),
            "major": (2, "partial_outage"),
            "critical": (3, "major_outage"),
            "maintenance": (4, "maintenance"),
        }
        return mapping.get(indicator, (1, "degraded"))
