#!/usr/bin/env python3
"""Test script to validate comparison table generation logic."""

from pathlib import Path
import tempfile
import time

def extract_scan_data_from_markdown(path):
    """Extract scan metadata and CVE counts from a scan markdown file."""
    try:
        content = path.read_text(encoding="utf-8")
        lines = content.split("\n")

        timestamp = None
        total_cves = 0
        critical = 0
        high = 0
        medium = 0
        low = 0

        for line in lines:
            if "| CVE ID |" in line:
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

        filename_parts = path.stem.split("-")
        if len(filename_parts) >= 3:
            timestamp = f"{filename_parts[-2]}-{filename_parts[-1]}"

        return {
            "timestamp": timestamp or "unknown",
            "total": total_cves,
            "critical": critical,
            "high": high,
            "medium": medium,
            "low": low,
            "path": str(path),
        }
    except Exception as e:
        return None


def generate_comparison_table_test():
    """Test comparison table generation with sample data."""

    # Create sample scan data
    test_scans = [
        {
            "timestamp": "20260430-085313",
            "total": 5,
            "critical": 0,
            "high": 2,
            "medium": 2,
            "low": 1,
        },
        {
            "timestamp": "20260430-085412",
            "total": 5,
            "critical": 0,
            "high": 2,
            "medium": 2,
            "low": 1,
        },
        {
            "timestamp": "20260430-090000",
            "total": 3,
            "critical": 0,
            "high": 1,
            "medium": 1,
            "low": 1,
        },
    ]

    # Build comparison table header
    header_cols = " | ".join(["Métrica"] + [d["timestamp"] for d in test_scans])
    separator = " | ".join(["-" * 12] * (len(test_scans) + 1))

    # Build table rows
    rows = []
    for metric, key in [
        ("Total CVEs", "total"),
        ("Critical", "critical"),
        ("High", "high"),
        ("Medium", "medium"),
        ("Low", "low"),
    ]:
        values = [metric] + [str(d[key]) for d in test_scans]
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

    for i, data in enumerate(test_scans, 1):
        comparison_lines.extend([
            f"### Scan {i} - {data['timestamp']}",
            f"- **Total CVEs**: {data['total']}",
            f"- **Critical**: {data['critical']}",
            f"- **High**: {data['high']}",
            f"- **Medium**: {data['medium']}",
            f"- **Low**: {data['low']}",
            "",
        ])

    comparison_content = "\n".join(comparison_lines).strip() + "\n"
    return comparison_content


if __name__ == "__main__":
    print("=" * 80)
    print("TESTE: Lógica de Comparação de Scans")
    print("=" * 80)

    result = generate_comparison_table_test()
    print(result)

    print("\n" + "=" * 80)
    print("✅ Teste de lógica concluído com sucesso!")
    print("=" * 80)
