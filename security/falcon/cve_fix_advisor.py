#!/usr/bin/env python3
"""Analyze CrowdStrike CVE report and generate a proposed Dockerfile.

This tool never edits the original Dockerfile. It reads a CrowdStrike JSON report,
extracts package upgrade opportunities, and writes a new proposed Dockerfile file
that operators can review and copy/paste manually.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
import time
from typing import Any


NO_FIX_VALUES = {"", "n/a", "no fix", "none", "unknown"}


class AdvisorError(RuntimeError):
    """Domain-specific runtime error for advisor failures."""


def info(message: str) -> None:
    print(f"[INFO] {message}")


def warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a proposed Dockerfile with CVE remediation hints.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--report-json", required=True, help="Path to CrowdStrike JSON report")
    parser.add_argument("--dockerfile", required=True, help="Path to source Dockerfile")
    parser.add_argument("--output-dir", required=True, help="Directory where proposed files will be saved")
    parser.add_argument("--image", default="", help="Image identifier for report metadata")
    return parser.parse_args()


def normalize_text(value: Any) -> str:
    return str(value or "").strip()


def extract_fixed_from_description(description: str) -> str:
    patterns = [
        r"fixed in version\s+([0-9][0-9A-Za-z_.-]*)",
        r"version\s+([0-9][0-9A-Za-z_.-]*)\s+fixes",
        r"fixed in\s+([0-9][0-9A-Za-z_.-]*)",
    ]
    for pattern in patterns:
        match = re.search(pattern, description, flags=re.IGNORECASE)
        if match:
            return normalize_text(match.group(1))
    return ""


def extract_crowdstrike_findings(data: dict[str, Any]) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []
    for item in data.get("Vulnerabilities") or []:
        vuln = item.get("Vulnerability") or {}
        product = vuln.get("Product") or {}
        details = vuln.get("Details") or {}

        cve = normalize_text(vuln.get("CVEID"))
        package = normalize_text(product.get("Product"))
        installed = normalize_text(product.get("MajorVersion"))
        fixed_versions = vuln.get("FixedVersions") or []
        fixed = normalize_text(fixed_versions[0]) if fixed_versions else ""
        description = normalize_text(details.get("description"))

        if not fixed:
            fixed = extract_fixed_from_description(description)

        findings.append(
            {
                "cve": cve or "UNKNOWN",
                "package": package or "unknown-package",
                "installed": installed or "unknown",
                "fixed": fixed,
                "description": description,
            }
        )
    return findings


def is_python_finding(finding: dict[str, str]) -> bool:
    desc = finding.get("description", "").lower()
    package = finding.get("package", "").lower()
    python_keywords = {"pip", "setuptools", "wheel", "requests", "python", "site-packages"}
    if package in python_keywords:
        return True
    return "site-packages" in desc or "python package" in desc


def build_remediation_plan(findings: list[dict[str, str]]) -> tuple[dict[str, str], list[dict[str, str]]]:
    pip_updates: dict[str, str] = {}
    unresolved: list[dict[str, str]] = []

    for finding in findings:
        package = finding["package"]
        fixed = normalize_text(finding.get("fixed"))
        fixed_lc = fixed.lower()

        if fixed_lc in NO_FIX_VALUES:
            unresolved.append(finding)
            continue

        if is_python_finding(finding):
            if package not in pip_updates:
                pip_updates[package] = fixed
            continue

        unresolved.append(finding)

    return pip_updates, unresolved


def build_proposed_dockerfile(original: str, pip_updates: dict[str, str], unresolved: list[dict[str, str]]) -> str:
    content = original.rstrip() + "\n\n"
    content += "# --- Security remediation proposal (generated) ---\n"
    content += "# This is a proposal file. Review before applying to your real Dockerfile.\n"

    if pip_updates:
        content += "RUN python -m pip install --no-cache-dir --upgrade \\\n"
        items = [f"    {name}=={version}" for name, version in sorted(pip_updates.items())]
        content += " \\\n".join(items)
        content += "\n"
    else:
        content += "# No direct pip upgrade suggestion could be generated from current findings.\n"

    if unresolved:
        content += "\n# Manual review required for findings without safe automatic suggestion:\n"
        for finding in unresolved:
            content += (
                f"# - {finding['cve']} | package={finding['package']} | "
                f"installed={finding['installed']} | fixed={finding.get('fixed') or 'N/A'}\n"
            )

    return content


def build_markdown_summary(
    image: str,
    dockerfile: Path,
    proposed_file: Path,
    findings: list[dict[str, str]],
    pip_updates: dict[str, str],
    unresolved: list[dict[str, str]],
) -> str:
    lines = [
        "# CVE Fix Advisor",
        "",
        f"- Image: `{image or 'unknown'}`",
        f"- Source Dockerfile: `{dockerfile}`",
        f"- Proposed Dockerfile: `{proposed_file}`",
        f"- Findings parsed: `{len(findings)}`",
        f"- Auto suggestions (pip): `{len(pip_updates)}`",
        f"- Manual review items: `{len(unresolved)}`",
        "",
        "## Suggested package updates",
        "",
    ]

    if pip_updates:
        for name, version in sorted(pip_updates.items()):
            lines.append(f"- `{name}` -> `{version}`")
    else:
        lines.append("- No direct pip package update could be suggested")

    lines.extend(["", "## Manual review items", ""])
    if unresolved:
        for finding in unresolved:
            lines.append(
                f"- `{finding['cve']}` | package `{finding['package']}` | "
                f"installed `{finding['installed']}` | fixed `{finding.get('fixed') or 'N/A'}`"
            )
    else:
        lines.append("- None")

    return "\n".join(lines).strip() + "\n"


def main() -> int:
    args = parse_args()

    report_path = Path(args.report_json).expanduser().resolve()
    dockerfile_path = Path(args.dockerfile).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()

    if not report_path.exists():
        raise AdvisorError(f"CrowdStrike report not found: {report_path}")
    if not dockerfile_path.exists():
        raise AdvisorError(f"Dockerfile not found: {dockerfile_path}")

    with report_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    if not isinstance(payload, dict) or "Vulnerabilities" not in payload:
        raise AdvisorError("Unsupported report format. Expected CrowdStrike image JSON with 'Vulnerabilities'.")

    findings = extract_crowdstrike_findings(payload)
    pip_updates, unresolved = build_remediation_plan(findings)

    original_dockerfile = dockerfile_path.read_text(encoding="utf-8")
    proposed_content = build_proposed_dockerfile(original_dockerfile, pip_updates, unresolved)

    output_dir.mkdir(parents=True, exist_ok=True)
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    proposed_path = output_dir / f"Dockerfile.proposed-{timestamp}"
    summary_path = output_dir / f"cve-fix-advice-{timestamp}.md"

    proposed_path.write_text(proposed_content, encoding="utf-8")
    summary_path.write_text(
        build_markdown_summary(
            image=args.image,
            dockerfile=dockerfile_path,
            proposed_file=proposed_path,
            findings=findings,
            pip_updates=pip_updates,
            unresolved=unresolved,
        ),
        encoding="utf-8",
    )

    info(f"Novo Dockerfile proposto salvo em: {proposed_path}")
    info(f"Caminho de saida para copy/paste: {output_dir}")
    info(f"Resumo de recomendacoes salvo em: {summary_path}")
    print("\n===== BEGIN PROPOSED DOCKERFILE =====\n")
    print(proposed_content.rstrip())
    print("\n===== END PROPOSED DOCKERFILE =====\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AdvisorError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
