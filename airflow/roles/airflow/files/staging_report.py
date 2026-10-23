"""
staging_report — a fun end-to-end demo pipeline for the staging VM.

Pipeline shape:

    greet >> extract >> transform >> load >> celebrate
                        \>>> (fan-out)

    * greet      : prints a friendly banner
    * extract    : collects real system facts (OS, uptime, RAM, disk) -> XCom
    * transform  : builds a decorated Markdown-ish report from the XCom data
    * load       : writes the report to /opt/airflow/staging_report.txt
    * celebrate  : ASCII celebration + where to find the report

Designed for the servers-staging Ansible role (Airflow 2.x, LocalExecutor).
Inspired by the official tutorial: https://airflow.apache.org/docs/apache-airflow/stable/tutorial/fundamentals.html
"""

import json
import platform
import shutil
import subprocess
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

REPORT_PATH = "/opt/airflow/staging_report.txt"

DEFAULT_ARGS = {
    "owner": "staging-team",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
}


def _banner():
    print("=" * 62)
    print("  🚀  STAGING DAILY REPORT — pipelines that spark joy  🚀")
    print("=" * 62)


def _extract(**context):
    """Collect real facts about this machine and push them via XCom."""
    os_release = {}
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    os_release[k] = v.strip('"')
    except OSError:
        os_release["PRETTY_NAME"] = "unknown"

    uptime = subprocess.run(
        ["uptime", "-p"], capture_output=True, text=True
    ).stdout.strip() or "unknown"

    mem_total_line = subprocess.run(
        ["free", "-m"], capture_output=True, text=True
    ).stdout.splitlines()
    mem_mb = "?"
    if len(mem_total_line) > 1:
        mem_mb = mem_total_line[1].split()[1]

    disk_gb = "?"
    usage = shutil.disk_usage("/")
    disk_gb = f"{usage.used // (2 ** 30)}/{usage.total // (2 ** 30)}"

    facts = {
        "hostname": platform.node(),
        "os": os_release.get("PRETTY_NAME", "unknown"),
        "kernel": platform.release(),
        "python": platform.python_version(),
        "uptime": uptime,
        "ram_mb": mem_mb,
        "disk_used_total_gb": disk_gb,
        "extracted_at": datetime.utcnow().isoformat() + "Z",
    }
    print("Extracted facts:")
    for k, v in facts.items():
        print(f"   • {k:>20} : {v}")
    return facts


def _transform(**context):
    """Turn the raw facts into a decorated report (pulled from XCom)."""
    ti = context["ti"]
    facts = ti.xcom_pull(task_ids="extract")

    lines = [
        "#" * 62,
        f"#  STAGING REPORT — {facts['hostname']}",
        "#" * 62,
        "",
        f"  OS ........: {facts['os']}",
        f"  Kernel ....: {facts['kernel']}",
        f"  Python ....: {facts['python']}",
        f"  Uptime ....: {facts['uptime']}",
        f"  RAM .......: {facts['ram_mb']} MB total",
        f"  Disk ......: {facts['disk_used_total_gb']} GB (used/total)",
        f"  Collected .: {facts['extracted_at']}",
        "",
        "  ✅ All systems nominal. Airflow is alive and well.",
        "#" * 62,
    ]
    report = "\n".join(lines)
    print(report)
    return report


def _load(**context):
    """Write the report to disk so it can be read from the VM."""
    ti = context["ti"]
    report = ti.xcom_pull(task_ids="transform")
    with open(REPORT_PATH, "w") as f:
        f.write(report + "\n")
    print(f"Report written to {REPORT_PATH}")
    return REPORT_PATH


with DAG(
    dag_id="staging_report",
    description="🎨 A joyful demo pipeline: system facts -> report -> celebration",
    default_args=DEFAULT_ARGS,
    schedule="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["example", "staging", "demo"],
    doc_md=__doc__,
) as dag:
    dag.doc_md = __doc__

    greet = BashOperator(
        task_id="greet",
        bash_command=(
            'echo "=============================================="; '
            'echo " 🚀 Hello staging! Dashboard pipeline starting "; '
            'echo "=============================================="'
        ),
    )
    greet.doc_md = "Prints a friendly banner. Every good pipeline starts politely."

    extract = PythonOperator(
        task_id="extract",
        python_callable=_extract,
    )
    extract.doc_md = "Collects OS, kernel, uptime, RAM and disk facts via XCom."

    transform = PythonOperator(
        task_id="transform",
        python_callable=_transform,
    )
    transform.doc_md = "Builds the decorated report from the extracted facts."

    load = PythonOperator(
        task_id="load",
        python_callable=_load,
    )
    load.doc_md = f"Writes the report to `{REPORT_PATH}` on the VM."

    celebrate = BashOperator(
        task_id="celebrate",
        bash_command=(
            'echo ""; echo "   🎉 Report generated successfully! 🎉"; '
            f'echo "   📄 Available at {REPORT_PATH}"; echo ""; '
            'echo "        \\\\  /  /"; echo "         \\\\ \\/ /"; echo "          \\\\ /"; '
            'echo "        SUCCESS!"'
        ),
    )
    celebrate.trigger_rule = "all_success"

    greet >> extract >> transform >> load >> celebrate
