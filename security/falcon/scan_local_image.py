#!/usr/bin/env python3
"""Scan a local container image with CrowdStrike FCS and save a Markdown report.

This script bootstraps an isolated virtual environment on first run, installs
its Python dependency with pip, retrieves the Falcon client secret from AWS
Secrets Manager, downloads the latest CrowdStrike FCS CLI for the current
platform, scans a local image from the container engine, prints the final
report, and saves it under ~/Documents/scan-image/.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import venv
import zipfile
from typing import Any

DEFAULT_SECRET_ARN = "FALCON_SCAN/FALCON_CLIENT_SECRET"
DEFAULT_CLIENT_ID_SECRET_ARN = "FALCON_SCAN/FALCON_CLIENT_ID"
DEFAULT_AWS_REGION = "us-east-1"
DEFAULT_FALCON_REGION = "us-2"
DEFAULT_OUTPUT_DIR = Path.home() / "Documents" / "scan-image"
DEFAULT_CACHE_DIR = Path.home() / ".cache" / "base-images-scan-image"
INTERNAL_VENV_FLAG = "--_in-venv"
VENV_ENV_VAR = "BASE_IMAGES_SCAN_IN_VENV"
REQUESTS_VERSION = "2.32.3"


class ScanError(RuntimeError):
    """Domain-specific runtime error for scan failures."""


def info(message: str) -> None:
    print(f"[INFO] {message}")


def warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def error(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def parser_script_path() -> Path:
    return repo_root() / ".github" / "scripts" / "crowdstrike_sarif_to_markdown.py"


def advisor_script_path() -> Path:
    return repo_root() / "scripts" / "cve_fix_advisor.py"


def venv_dir() -> Path:
    return DEFAULT_CACHE_DIR / ".venv"


def venv_python_path() -> Path:
    if os.name == "nt":
        return venv_dir() / "Scripts" / "python.exe"
    return venv_dir() / "bin" / "python"


def ensure_venv_and_reexec() -> None:
    if INTERNAL_VENV_FLAG in sys.argv or os.environ.get(VENV_ENV_VAR) == "1":
        return

    target_dir = venv_dir()
    python_bin = venv_python_path()
    marker = target_dir / ".requests-version"

    if not python_bin.exists():
        info(f"Criando ambiente virtual isolado em {target_dir}")
        builder = venv.EnvBuilder(with_pip=True, clear=False, symlinks=True, upgrade=False)
        builder.create(target_dir)

    installed_version = marker.read_text(encoding="utf-8").strip() if marker.exists() else ""
    if installed_version != REQUESTS_VERSION:
        info("Instalando dependencias Python no ambiente isolado")
        subprocess.run(
            [
                str(python_bin),
                "-m",
                "pip",
                "install",
                "--disable-pip-version-check",
                f"requests=={REQUESTS_VERSION}",
            ],
            check=True,
        )
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text(REQUESTS_VERSION, encoding="utf-8")

    env = os.environ.copy()
    env[VENV_ENV_VAR] = "1"
    args = [str(python_bin), str(Path(__file__).resolve()), INTERNAL_VENV_FLAG, *sys.argv[1:]]
    raise SystemExit(subprocess.call(args, env=env))


def parse_args() -> argparse.Namespace:
    argv = [arg for arg in sys.argv[1:] if arg != INTERNAL_VENV_FLAG]
    parser = argparse.ArgumentParser(
        description="Valida uma imagem local com CrowdStrike FCS e salva o relatorio em Markdown.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("image", help="Nome ou ID da imagem local (ex.: my-app:latest ou sha256:...)" )
    parser.add_argument("--falcon-client-id", default=os.environ.get("FALCON_CLIENT_ID", ""), help="Falcon Client ID. Se omitido, tenta obter do secret JSON ou da variavel FALCON_CLIENT_ID.")
    parser.add_argument("--falcon-region", default=os.environ.get("FALCON_REGION", DEFAULT_FALCON_REGION), help="Regiao Falcon usada para obter token e baixar o FCS CLI")
    parser.add_argument("--aws-region", default=os.environ.get("AWS_REGION", DEFAULT_AWS_REGION), help="Regiao AWS usada para consultar o secret")
    parser.add_argument("--secret-arn", default=DEFAULT_SECRET_ARN, help="ARN do secret no AWS Secrets Manager que contem o Falcon client secret")
    parser.add_argument(
        "--client-id-secret-arn",
        default=os.environ.get("FALCON_CLIENT_ID_SECRET_ARN", DEFAULT_CLIENT_ID_SECRET_ARN),
        help=(
            "ARN/nome do secret AWS que contem o Falcon client id. "
            "Por padrao usa FALCON_SCAN/FALCON_CLIENT_ID."
        ),
    )
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="Diretorio onde o relatorio Markdown sera salvo")
    parser.add_argument("--platform", default="", help="Platform opcional para o scan (ex.: linux/amd64)")
    parser.add_argument("--fcs-version", default="", help="Versao opcional do FCS CLI; vazio usa a mais recente")
    parser.add_argument("--report-limit", type=int, default=30, help="Quantidade maxima de findings renderizados no Markdown")
    parser.add_argument("--minimum-severity", default="", help="Severidade minima opcional para o scan (low, medium, high, critical)")
    parser.add_argument("--minimum-score", default="", help="Score CVSS minimo opcional (0.0-10.0)")
    parser.add_argument("--socket", default="", help="Socket do container runtime (ex.: unix:///var/run/docker.sock). Autodetectado se nao informado")
    parser.add_argument("--fcs-timeout", type=int, default=600, help="Timeout em segundos para operacoes do FCS CLI (padrao: 600)")
    parser.add_argument(
        "--fix-advice",
        choices=("ask", "yes", "no"),
        default="ask",
        help="Executa analise opcional de correcoes CVE e gera Dockerfile proposto sem editar o original",
    )
    parser.add_argument(
        "--dockerfile-path",
        default="",
        help="Caminho do Dockerfile base para gerar o Dockerfile proposto (usado quando --fix-advice=yes)",
    )
    return parser.parse_args(argv)


def ensure_external_dependency(command: str) -> None:
    if shutil.which(command):
        return
    raise ScanError(f"Dependencia obrigatoria nao encontrada no PATH: {command}")


def run_command(command: list[str], *, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, env=env, check=check)


def verify_local_image(image: str) -> None:
    ensure_external_dependency("docker")
    result = run_command(["docker", "image", "inspect", image], check=False)
    if result.returncode != 0:
        raise ScanError(
            f"Imagem local nao encontrada ou Docker indisponivel: {image}\n"
            f"Saida do docker: {(result.stderr or result.stdout).strip()}"
        )


def resolve_scannable_image_reference(image: str) -> tuple[str, str, str]:
    """Export the local image to a cached tar file and return its path.

    FCS CLI supports scanning local tar files directly (fcs scan image /path/to.tar),
    which avoids any attempt to pull the image from a remote registry.
    The tar is cached by image ID so repeated scans of the same image are fast.
    Returns (tar_path, image_name, image_short_id).
    image_name is the first RepoTag or empty string if untagged.
    """
    inspect = run_command(["docker", "image", "inspect", image], check=False)
    if inspect.returncode != 0:
        raise ScanError(
            f"Nao foi possivel inspecionar a imagem local: {image}\n"
            f"Saida do docker: {(inspect.stderr or inspect.stdout).strip()}"
        )

    try:
        payload = json.loads(inspect.stdout)
    except json.JSONDecodeError as exc:
        raise ScanError(f"Falha ao interpretar docker inspect para a imagem {image}: {exc}") from exc

    if not isinstance(payload, list) or not payload:
        raise ScanError(f"docker inspect retornou um formato inesperado para a imagem {image}")

    first = payload[0] if isinstance(payload[0], dict) else {}
    image_id = str(first.get("Id") or "").strip().replace("sha256:", "")[:12] or "local"
    repo_tags = first.get("RepoTags") or []
    image_name = str(repo_tags[0]).strip() if repo_tags and str(repo_tags[0]).strip() != "<none>:<none>" else ""

    tar_dir = DEFAULT_CACHE_DIR / "tar-export"
    tar_dir.mkdir(parents=True, exist_ok=True)
    tar_path = str(tar_dir / f"{image_id}.tar")

    if Path(tar_path).exists():
        info(f"Usando tar em cache: {tar_path}")
    else:
        info(f"Exportando imagem para tar: {tar_path}")
        save_result = run_command(["docker", "save", image, "-o", tar_path], check=False)
        if save_result.returncode != 0:
            raise ScanError(
                f"Falha ao exportar imagem {image} para tar.\n"
                f"Saida do docker: {(save_result.stderr or save_result.stdout).strip()}"
            )

    return tar_path, image_name, image_id


def cleanup_temp_tar(tar_path: str) -> None:
    """Remove a cached tar file generated for scan input."""
    if not tar_path:
        return

    path = Path(tar_path)
    if not path.exists():
        return

    try:
        path.unlink()
        info(f"Tar temporario removido: {path}")
    except Exception:
        warn(f"Falha ao remover tar temporario: {path}")


def cleanup_tar_export_cache() -> None:
    """Remove leftover tar exports to avoid disk growth over time."""
    tar_dir = DEFAULT_CACHE_DIR / "tar-export"
    if not tar_dir.exists():
        return

    for tar_file in tar_dir.glob("*.tar"):
        try:
            tar_file.unlink()
            info(f"Tar de cache removido: {tar_file}")
        except Exception:
            warn(f"Falha ao remover tar de cache: {tar_file}")


def aws_get_secret_string(secret_arn: str, aws_region: str) -> str:
    ensure_external_dependency("aws")

    identity = run_command(["aws", "sts", "get-caller-identity", "--output", "json"], check=False)
    if identity.returncode == 0 and identity.stdout.strip():
        try:
            payload = json.loads(identity.stdout)
            info(f"AWS account em uso: {payload.get('Account', 'desconhecida')}")
        except json.JSONDecodeError:
            warn("Nao foi possivel interpretar aws sts get-caller-identity; seguindo assim mesmo")
    else:
        warn("Nao foi possivel validar a identidade AWS atual antes de consultar o secret")

    result = run_command(
        [
            "aws",
            "secretsmanager",
            "get-secret-value",
            "--secret-id",
            secret_arn,
            "--region",
            aws_region,
            "--query",
            "SecretString",
            "--output",
            "text",
        ],
        check=False,
    )
    if result.returncode != 0:
        raise ScanError(
            "Falha ao consultar o secret no AWS Secrets Manager. "
            "Garanta que voce esteja autenticado na conta correta e tenha permissao de leitura.\n"
            f"Saida AWS CLI: {(result.stderr or result.stdout).strip()}"
        )
    return result.stdout.strip()



def aws_try_get_secret_string(secret_arn: str, aws_region: str) -> str:
    """Best-effort secret lookup that returns empty string on failure."""
    result = run_command(
        [
            "aws",
            "secretsmanager",
            "get-secret-value",
            "--secret-id",
            secret_arn,
            "--region",
            aws_region,
            "--query",
            "SecretString",
            "--output",
            "text",
        ],
        check=False,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def derive_client_id_secret_candidates(primary_secret_arn: str, explicit_client_id_secret_arn: str) -> list[str]:
    candidates: list[str] = []
    if explicit_client_id_secret_arn.strip():
        candidates.append(explicit_client_id_secret_arn.strip())

    derived = primary_secret_arn
    replacements = [
        ("FALCON_CLIENT_SECRET", "FALCON_CLIENT_ID"),
        ("falcon_client_secret", "falcon_client_id"),
        ("CLIENT_SECRET", "CLIENT_ID"),
        ("client_secret", "client_id"),
    ]
    for old, new in replacements:
        if old in derived:
            derived = derived.replace(old, new)

    if derived != primary_secret_arn:
        candidates.append(derived)

    # Fallback names for accounts that store the value by name instead of full ARN.
    candidates.extend(["FALCON_CLIENT_ID", "falcon_client_id"])

    deduped: list[str] = []
    seen = set()
    for candidate in candidates:
        if candidate and candidate not in seen:
            seen.add(candidate)
            deduped.append(candidate)
    return deduped


def resolve_client_id_from_aws(
    primary_secret_arn: str,
    explicit_client_id_secret_arn: str,
    aws_region: str,
) -> str:
    for candidate in derive_client_id_secret_candidates(primary_secret_arn, explicit_client_id_secret_arn):
        value = aws_try_get_secret_string(candidate, aws_region)
        if value:
            info(f"Falcon client id resolvido a partir do secret: {candidate}")
            try:
                parsed = json.loads(value)
            except json.JSONDecodeError:
                parsed = None

            if isinstance(parsed, dict):
                for key in ("FALCON_CLIENT_ID", "falcon_client_id", "client_id", "value"):
                    nested = parsed.get(key)
                    if nested:
                        return str(nested).strip()
            return value.strip()
    return ""


def resolve_falcon_credentials(
    secret_string: str,
    falcon_client_id: str,
    primary_secret_arn: str,
    client_id_secret_arn: str,
    aws_region: str,
) -> tuple[str, str]:
    client_secret = secret_string.strip()
    candidate_client_id = falcon_client_id.strip()

    try:
        parsed = json.loads(secret_string)
    except json.JSONDecodeError:
        parsed = None

    if isinstance(parsed, dict):
        for key in ("FALCON_CLIENT_SECRET", "falcon_client_secret", "client_secret", "secret", "value"):
            value = parsed.get(key)
            if value:
                client_secret = str(value).strip()
                break
        if not candidate_client_id:
            for key in ("FALCON_CLIENT_ID", "falcon_client_id", "client_id"):
                value = parsed.get(key)
                if value:
                    candidate_client_id = str(value).strip()
                    break

    if not client_secret:
        raise ScanError("O secret retornado pela AWS nao contem um Falcon client secret utilizavel")
    if not candidate_client_id:
        candidate_client_id = resolve_client_id_from_aws(primary_secret_arn, client_id_secret_arn, aws_region)
    if not candidate_client_id:
        raise ScanError(
            "Falcon client id ausente. O script tenta obter automaticamente via AWS Secrets Manager, "
            "mas nenhum valor foi encontrado. Verifique os secrets FALCON_SCAN/FALCON_CLIENT_ID e "
            "FALCON_SCAN/FALCON_CLIENT_SECRET."
        )
    return candidate_client_id, client_secret


def falcon_api_host(region: str) -> str:
    mapping = {
        "us-1": "api.crowdstrike.com",
        "us-2": "api.us-2.crowdstrike.com",
        "eu-1": "api.eu-1.crowdstrike.com",
        "us-gov-1": "api.laggar.gcw.crowdstrike.com",
        "us-gov-2": "api.us-gov-2.crowdstrike.mil",
    }
    return mapping.get(region, "api.crowdstrike.com")


def detect_download_platform() -> tuple[str, str]:
    system = platform.system().lower()
    machine = platform.machine().lower()

    if system.startswith("linux"):
        os_name = "linux"
    elif system.startswith("darwin"):
        os_name = "darwin"
    elif system.startswith("win"):
        os_name = "windows"
    else:
        warn(f"Sistema operacional nao reconhecido ({system}); assumindo linux")
        os_name = "linux"

    if machine in {"aarch64", "arm64"}:
        arch = "arm64"
    elif machine in {"x86_64", "amd64"}:
        arch = "amd64"
    else:
        warn(f"Arquitetura nao reconhecida ({machine}); assumindo amd64")
        arch = "amd64"

    return os_name, arch


def get_requests_module():
    import requests  # type: ignore

    return requests


def get_oauth_token(client_id: str, client_secret: str, region: str) -> str:
    requests = get_requests_module()
    response = requests.post(
        f"https://{falcon_api_host(region)}/oauth2/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "grant_type": "client_credentials",
        },
        timeout=30,
    )
    if response.status_code not in (200, 201):
        raise ScanError(
            f"Falha ao obter token OAuth do CrowdStrike (HTTP {response.status_code}): {response.text[:500]}"
        )

    payload = response.json()
    token = payload.get("access_token")
    if not token:
        raise ScanError("Resposta OAuth do CrowdStrike nao contem access_token")
    return str(token)


def get_fcs_download_metadata(token: str, region: str, version: str) -> dict[str, Any]:
    requests = get_requests_module()
    os_name, arch = detect_download_platform()
    filter_value = f"category:'fcs'+os:'{os_name}'+arch:'{arch}'"
    if version:
        filter_value += f"+file_version:'{version}'"

    response = requests.get(
        f"https://{falcon_api_host(region)}/csdownloads/combined/files-download/v2",
        headers={"Authorization": f"Bearer {token}", "accept": "application/json"},
        params={"filter": filter_value, "limit": 100, "sort": "file_version|desc"},
        timeout=60,
    )
    if response.status_code != 200:
        raise ScanError(
            f"Falha ao consultar metadados do FCS CLI (HTTP {response.status_code}): {response.text[:500]}"
        )

    payload = response.json()
    resources = payload.get("resources") or []
    if not resources:
        raise ScanError("Nenhum binario FCS foi retornado pela API de download")
    return resources[0]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def extract_fcs_binary(archive_path: Path, destination_dir: Path) -> Path:
    with tempfile.TemporaryDirectory(prefix="fcs-extract-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        if archive_path.suffixes[-2:] == [".tar", ".gz"]:
            with tarfile.open(archive_path, "r:gz") as tar:
                tar.extractall(temp_dir)
        elif archive_path.suffix.lower() == ".zip":
            with zipfile.ZipFile(archive_path, "r") as zip_handle:
                zip_handle.extractall(temp_dir)
        else:
            raise ScanError(f"Formato de arquivo FCS nao suportado: {archive_path.name}")

        candidates = list(temp_dir.rglob("fcs")) + list(temp_dir.rglob("fcs.exe"))
        if not candidates:
            raise ScanError("O arquivo baixado nao contem o binario fcs")

        destination_dir.mkdir(parents=True, exist_ok=True)
        binary_name = "fcs.exe" if os.name == "nt" else "fcs"
        destination = destination_dir / binary_name
        shutil.copy2(candidates[0], destination)
        current_mode = destination.stat().st_mode
        destination.chmod(current_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    (Path.home() / ".crowdstrike" / "log").mkdir(parents=True, exist_ok=True)
    return destination


def download_fcs_cli(client_id: str, client_secret: str, falcon_region: str, version: str) -> tuple[Path, str]:
    token = get_oauth_token(client_id, client_secret, falcon_region)
    metadata = get_fcs_download_metadata(token, falcon_region, version)

    file_version = str(metadata.get("file_version") or version or "latest")
    cache_target = DEFAULT_CACHE_DIR / "fcs" / file_version
    binary_name = "fcs.exe" if os.name == "nt" else "fcs"
    cached_binary = cache_target / binary_name
    if cached_binary.exists():
        info(f"Usando FCS CLI em cache: {cached_binary}")
        return cached_binary, file_version

    download_info = metadata.get("download_info") or {}
    download_url = str(download_info.get("download_url") or "")
    expected_hash = str(download_info.get("file_hash") or metadata.get("file_hash") or "")
    file_name = str(metadata.get("file_name") or "")
    if not download_url or not expected_hash or not file_name:
        raise ScanError("Resposta da API de download do FCS nao contem download_url, file_hash e file_name")

    info(f"Baixando FCS CLI versao {file_version}")
    requests = get_requests_module()
    with tempfile.TemporaryDirectory(prefix="fcs-download-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        archive_path = temp_dir / file_name
        with requests.get(download_url, stream=True, timeout=300) as response:
            response.raise_for_status()
            with archive_path.open("wb") as handle:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        handle.write(chunk)

        actual_hash = sha256_file(archive_path)
        if actual_hash.lower() != expected_hash.lower():
            raise ScanError(
                f"Hash do arquivo FCS invalido. Esperado {expected_hash}, obtido {actual_hash}"
            )

        binary = extract_fcs_binary(archive_path, cache_target)
        return binary, file_version


def _resolve_socket(explicit: str) -> str:
    """Return socket URI to pass to FCS --socket flag.
    If an explicit value is given, use it.  Otherwise probe common paths."""
    if explicit:
        return explicit
    candidates = [
        "/var/run/docker.sock",
        "/run/docker.sock",
    ]
    for path in candidates:
        if os.path.exists(path):
            return f"unix://{path}"
    return ""


def run_fcs_scan(binary_path: Path, image: str, output_json: Path, args: argparse.Namespace, client_id: str, client_secret: str) -> tuple[int, str]:
    env = os.environ.copy()
    env["FCS_CLIENT_ID"] = client_id
    env["FCS_CLIENT_SECRET"] = client_secret

    command = [
        str(binary_path),
        "scan",
        "image",
        image,
        "--output",
        str(output_json),
        "--format",
        "json",
        "--show-full-description",
        "--no-color",
    ]
    if args.platform:
        command.extend(["--platform", args.platform])
    if args.minimum_severity:
        command.extend(["--minimum-severity", args.minimum_severity])
    if args.minimum_score:
        command.extend(["--minimum-score", args.minimum_score])
    command.extend(["--timeout", str(getattr(args, "fcs_timeout", 600))])

    info("Executando scan CrowdStrike FCS na imagem local")
    result = subprocess.run(command, text=True, capture_output=True, env=env, check=False)
    combined_output = "\n".join(part for part in (result.stdout.strip(), result.stderr.strip()) if part)
    return result.returncode, combined_output


def render_markdown_rows(report_path: Path, limit: int) -> str:
    parser_script = parser_script_path()
    if not parser_script.exists():
        raise ScanError(f"Parser do CrowdStrike nao encontrado em {parser_script}")

    result = subprocess.run(
        [sys.executable, str(parser_script), str(report_path), str(limit)],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise ScanError(
            "Falha ao converter o relatorio do CrowdStrike em Markdown. "
            f"Saida: {(result.stderr or result.stdout).strip()}"
        )
    return result.stdout.strip()


def sanitize_filename(value: str) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-.")
    return sanitized or "image"


def build_markdown_report(
    image: str,
    report_rows: str,
    report_path: Path,
    markdown_path: Path,
    scan_exit_code: int,
    fcs_version: str,
) -> str:
    findings = [line for line in report_rows.splitlines() if line.strip().startswith("|")]
    status = "Passed" if scan_exit_code == 0 else "Failed"
    lines = [
        "# CrowdStrike Security Scan",
        "",
        f"- Image: `{image}`",
        f"- Status: `{status}`",
        f"- FCS Version: `{fcs_version}`",
        f"- Exit Code: `{scan_exit_code}`",
        f"- Raw Report: `{report_path}`",
        f"- Markdown Report: `{markdown_path}`",
        "",
    ]

    if findings:
        lines.extend(
            [
                "## Vulnerability Details",
                "",
                "| CVE ID | Severity | CVSS Score | Package | Installed | Fixed In | Recommendation | Description |",
                "|--------|----------|------------|---------|-----------|----------|----------------|-------------|",
                *findings,
                "",
                f"Showing up to {len(findings)} finding(s) do relatorio processado.",
            ]
        )
    else:
        lines.extend(
            [
                "## Vulnerability Details",
                "",
                "Nenhum finding foi retornado pelo parser para este relatorio.",
            ]
        )

    return "\n".join(lines).strip() + "\n"


def save_report(markdown_path: Path, markdown: str) -> Path:
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.write_text(markdown, encoding="utf-8")
    return markdown_path


def cleanup_sensitive_variables() -> None:
    """Remove sensitive environment variables and clear FCS log that may contain trace data."""
    for key in ("FCS_CLIENT_ID", "FCS_CLIENT_SECRET"):
        if key in os.environ:
            os.environ[key] = ""  # Zero out
            del os.environ[key]  # Remove

    # Clear FCS log — it contains trace-ids and region info written by the FCS CLI.
    # The log itself never stores credentials, but we truncate it to avoid accumulation.
    fcs_log = Path.home() / ".crowdstrike" / "log" / "fcs.log"
    if fcs_log.exists():
        try:
            fcs_log.write_text("", encoding="utf-8")
        except Exception:
            pass


def cleanup_temp_files(raw_report_path: Path) -> None:
    """Clean up temporary report file after processing to markdown."""
    if raw_report_path and raw_report_path.exists():
        try:
            raw_report_path.unlink()
            info(f"Arquivo temporário deletado: {raw_report_path}")
        except Exception as exc:
            pass  # Silently ignore cleanup errors


def extract_scan_data_from_markdown(path: Path) -> dict[str, Any] | None:
    """Extract scan metadata and CVE counts from a scan markdown file."""
    try:
        content = path.read_text(encoding="utf-8")
        lines = content.split("\n")

        # Extract timestamp from lines (format: "- Image: `<id>`, Status: Passed, etc.")
        timestamp = None
        total_cves = 0
        critical = 0
        high = 0
        medium = 0
        low = 0

        for line in lines:
            # Look for "| CVE ID |..." table header to count rows below it
            if "| CVE ID |" in line:
                # Count vulnerability rows (lines with | at start)
                in_table = False
                for table_line in lines[lines.index(line) + 1:]:
                    if table_line.startswith("| ") and "CVE-" in table_line:
                        total_cves += 1
                        if "| HIGH |" in table_line or "HIGH" in table_line:
                            high += 1
                        elif "| CRITICAL |" in table_line or "CRITICAL" in table_line:
                            critical += 1
                        elif "| MEDIUM |" in table_line or "MEDIUM" in table_line:
                            medium += 1
                        elif "| LOW |" in table_line or "LOW" in table_line:
                            low += 1
                    elif table_line.startswith("|") and "CVE-" not in table_line and in_table:
                        break
                    in_table = True

        # Extract timestamp from filename: scan-*-*-YYYYMMDD-HHMMSS.md
        filename_parts = path.stem.split("-")
        if len(filename_parts) >= 3:
            timestamp = f"{filename_parts[-2]}-{filename_parts[-1]}"  # YYYYMMDD-HHMMSS

        return {
            "timestamp": timestamp or "unknown",
            "total": total_cves,
            "critical": critical,
            "high": high,
            "medium": medium,
            "low": low,
            "path": str(path),
        }
    except Exception:
        return None


def generate_comparison_table(output_dir: Path, image_name_sanitized: str) -> None:
    """Generate comparison table if 2+ scan results exist in output_dir."""
    try:
        # Find all scan markdown files
        scan_files = sorted(
            [f for f in output_dir.glob(f"scan-{image_name_sanitized}-*-*.md")],
            key=lambda p: p.stat().st_mtime
        )

        if len(scan_files) < 2:
            return  # Not enough scans for comparison

        # Extract data from each scan
        scans_data = []
        for scan_file in scan_files:
            data = extract_scan_data_from_markdown(scan_file)
            if data:
                scans_data.append(data)

        if len(scans_data) < 2:
            return  # Could not extract valid data

        # Build comparison table header
        header_cols = " | ".join(["Métrica"] + [d["timestamp"] for d in scans_data])
        separator = " | ".join(["-" * 12] * (len(scans_data) + 1))

        # Build table rows
        rows = []
        for metric, key in [
            ("Total CVEs", "total"),
            ("Critical", "critical"),
            ("High", "high"),
            ("Medium", "medium"),
            ("Low", "low"),
        ]:
            values = [metric] + [str(d[key]) for d in scans_data]
            rows.append(" | ".join(values))

        # Build comparison markdown
        comparison_lines = [
            "# Comparação de Scans",
            "",
            "Análise dinâmica de múltiplas execuções de scan da imagem.",
            "",
            "## Resumo Comparativo",
            "",
            f"| {header_cols} |",
            f"| {separator} |",
        ]
        for row in rows:
            comparison_lines.append(f"| {row} |")

        comparison_lines.extend([
            "",
            "## Detalhes dos Scans",
            "",
        ])

        for i, data in enumerate(scans_data, 1):
            comparison_lines.extend([
                f"### Scan {i} - {data['timestamp']}",
                f"- **Total CVEs**: {data['total']}",
                f"- **Critical**: {data['critical']}",
                f"- **High**: {data['high']}",
                f"- **Medium**: {data['medium']}",
                f"- **Low**: {data['low']}",
                f"- **Report**: [{Path(data['path']).name}]({Path(data['path']).name})",
                "",
            ])

        # Save comparison file with timestamp
        timestamp = time.strftime("%Y%m%d")
        comparison_path = output_dir / f"comparison-scan-{image_name_sanitized}-{timestamp}.md"
        comparison_content = "\n".join(comparison_lines).strip() + "\n"

        comparison_path.write_text(comparison_content, encoding="utf-8")
        info(f"Tabela de comparacao gerada: {comparison_path}")

    except Exception as exc:
        warn(f"Falha ao gerar tabela de comparacao: {exc}")


def ask_yes_no(prompt: str, default: bool = False) -> bool:
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        return default

    suffix = "[Y/n]" if default else "[y/N]"
    answer = input(f"{prompt} {suffix}: ").strip().lower()
    if not answer:
        return default
    return answer in {"y", "yes", "s", "sim"}


def maybe_run_fix_advisor(
    *,
    mode: str,
    dockerfile_path_arg: str,
    report_path: Path,
    output_dir: Path,
    image: str,
) -> None:
    should_run = mode == "yes"
    if mode == "ask":
        should_run = ask_yes_no(
            "Deseja analisar CVEs e gerar um Dockerfile proposto com correcoes?",
            default=False,
        )

    if not should_run:
        return

    source_dockerfile = dockerfile_path_arg.strip()
    if not source_dockerfile and (sys.stdin.isatty() and sys.stdout.isatty()):
        source_dockerfile = input("Informe o caminho do Dockerfile de origem: ").strip()

    if not source_dockerfile:
        warn("Dockerfile nao informado. Pulando analise de correcoes CVE.")
        return

    advisor_script = advisor_script_path()
    if not advisor_script.exists():
        warn(f"Script de analise de correcoes nao encontrado: {advisor_script}")
        return

    command = [
        sys.executable,
        str(advisor_script),
        "--report-json",
        str(report_path),
        "--dockerfile",
        source_dockerfile,
        "--output-dir",
        str(output_dir),
        "--image",
        image,
    ]

    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.stdout.strip():
        print(result.stdout)
    if result.stderr.strip():
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        warn("Analise de correcoes CVE concluiu com erro. O scan principal permanece valido.")


def main() -> int:
    ensure_venv_and_reexec()
    args = parse_args()
    client_id = ""
    client_secret = ""
    scan_image = ""

    try:
        verify_local_image(args.image)
        scan_image, image_name, image_id = resolve_scannable_image_reference(args.image)

        secret_string = aws_get_secret_string(args.secret_arn, args.aws_region)
        client_id, client_secret = resolve_falcon_credentials(
            secret_string,
            args.falcon_client_id,
            args.secret_arn,
            args.client_id_secret_arn,
            args.aws_region,
        )
        binary_path, fcs_version = download_fcs_cli(client_id, client_secret, args.falcon_region, args.fcs_version)

        base_output_dir = Path(args.output_dir).expanduser().resolve()
        timestamp = time.strftime("%Y%m%d-%H%M%S")
        # Filename: scan-<image-name>-<short-id>-<timestamp>
        # e.g.: scan-gcr.io-k8s-minikube-kicbase-v0.0.50-6da180ef5035-20260429-112804
        name_part = sanitize_filename(image_name) if image_name else ""
        id_part = sanitize_filename(image_id)
        output_subdir_name = sanitize_filename(image_name or args.image)
        output_dir = base_output_dir / output_subdir_name
        file_stem = f"scan-{name_part}-{id_part}" if name_part else f"scan-{id_part}"
        raw_report_path = output_dir / f"{file_stem}-{timestamp}.json"
        output_dir.mkdir(parents=True, exist_ok=True)
        info(f"Diretorio de saida da imagem: {output_dir}")

        scan_exit_code, cli_output = run_fcs_scan(binary_path, scan_image, raw_report_path, args, client_id, client_secret)
        if cli_output:
            print(cli_output)

        if not raw_report_path.exists():
            raise ScanError(
                "O CrowdStrike FCS nao gerou o arquivo de saida esperado. "
                "Veja a saida acima para detalhes."
            )

        rows = render_markdown_rows(raw_report_path, args.report_limit)
        markdown_path = output_dir / f"{file_stem}-{timestamp}.md"

        final_markdown = build_markdown_report(
            image=args.image,
            report_rows=rows,
            report_path=raw_report_path,
            markdown_path=markdown_path,
            scan_exit_code=scan_exit_code,
            fcs_version=fcs_version,
        )
        save_report(markdown_path, final_markdown)

        print("\n" + final_markdown)
        info(f"Relatorio salvo em: {markdown_path}")

        # Generate comparison table if 2+ scans exist
        generate_comparison_table(output_dir, sanitize_filename(image_name or args.image))

        maybe_run_fix_advisor(
            mode=args.fix_advice,
            dockerfile_path_arg=args.dockerfile_path,
            report_path=raw_report_path,
            output_dir=output_dir,
            image=args.image,
        )

        cleanup_temp_files(raw_report_path)
        return scan_exit_code
    except ScanError as exc:
        error(str(exc))
        return 1
    except Exception as exc:  # pragma: no cover - defensive error surfacing for local CLI usage
        error(f"Falha inesperada: {exc}")
        return 1
    except KeyboardInterrupt:
        error("Execucao interrompida pelo usuario")
        return 130
    finally:
        client_id = ""  # Zero out from memory
        client_secret = ""  # Zero out from memory
        cleanup_sensitive_variables()
        cleanup_temp_tar(scan_image)
        cleanup_tar_export_cache()


if __name__ == "__main__":
    raise SystemExit(main())
