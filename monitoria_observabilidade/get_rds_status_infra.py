#!/usr/bin/env python3
import argparse
import json
import logging
import os
import sys
from datetime import datetime, timedelta, timezone

import boto3
from opentelemetry import metrics
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

# Configura o logging
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO").upper(),
    format="[%(asctime)s] [%(levelname)s] - %(message)s",
)

# ===================== LOCK LOCAL =====================
LOCK_FILE = "/tmp/get_rds_status_infra.lock"


def acquire_lock():
    if os.path.exists(LOCK_FILE):
        logging.error("Lock file existe, já há uma execução ativa. Abortando.")
        sys.exit(1)
    with open(LOCK_FILE, "w") as f:
        f.write(str(os.getpid()))


def release_lock():
    if os.path.exists(LOCK_FILE):
        os.remove(LOCK_FILE)


# Inicializa o MeterProvider e Exporter OTLP
exporter = OTLPMetricExporter()
reader = PeriodicExportingMetricReader(exporter)
provider = MeterProvider(metric_readers=[reader])
metrics.set_meter_provider(provider)
meter = metrics.get_meter(__name__)

# Cria o instrumento updown counter
bu_teste_rds_metrics = meter.create_up_down_counter(
    name="bu_teste_rds_metrics", description="RDS metrics", unit="1"
)

# ===================== VARIÁVEIS PRINCIPAIS =====================
# business unit identifier
BU = "buteste"
# use script directory as default work_dir so templates next to the script are found
WORK_DIR = os.path.dirname(__file__)

# Mapeamento centralizado de engines e templates
ENGINE_MAPPING = {
    "mysql": {"matches": ["mysql", "aurora-mysql"], "template": "get-rds-status-infra-mysql.json"},
    "postgres": {"matches": ["postgres", "aurora-postgresql"], "template": "get-rds-status-infra-postgresql.json"},
    "mariadb": {"matches": ["mariadb"], "template": "get-rds-status-infra-mariadb.json"},
    "oracle": {"matches": ["oracle-ee", "oracle-se", "oracle-se1", "oracle-se2"], "template": "get-rds-status-infra-oracle.json"},
    "sqlserver": {"matches": ["sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"], "template": "get-rds-status-infra-sqlserver.json"},
}


# ===================== FUNÇÕES =====================
def assume_role(role_arn, session_name):
    try:
        sts = boto3.client("sts")
        assumed_role = sts.assume_role(RoleArn=role_arn, RoleSessionName=session_name)
        creds = assumed_role["Credentials"]
        logging.info(f"Assumiu a role '{role_arn}' com sucesso.")
        return boto3.Session(
            aws_access_key_id=creds["AccessKeyId"],
            aws_secret_access_key=creds["SecretAccessKey"],
            aws_session_token=creds["SessionToken"],
        )
    except Exception as e:
        logging.error(f"Falha ao assumir a role '{role_arn}': {e}")
        sys.exit(1)


def get_rds_instances(region, session):
    """Obtém todas as instâncias RDS usando paginação."""
    try:
        rds = session.client("rds", region_name=region)
        paginator = rds.get_paginator("describe_db_instances")
        pages = paginator.paginate()
        all_instances = [db for page in pages for db in page["DBInstances"]]
        logging.info(f"Encontradas {len(all_instances)} instâncias RDS na região {region}.")
        return {"DBInstances": all_instances}
    except Exception as e:
        logging.error(f"Falha ao descrever instâncias RDS na região {region}: {e}")
        return {"DBInstances": []}


def filter_instances_by_engine(all_instances, engine_family):
    """Filtra instâncias RDS com base na família do motor de banco de dados."""
    result = []
    target_engines = ENGINE_MAPPING.get(engine_family, {}).get("matches", [engine_family])

    for db in all_instances["DBInstances"]:
        if db["Engine"] in target_engines:
            result.append((db["DBInstanceIdentifier"], db["Engine"]))
    return result


def select_rds_template(engine_name):
    """Seleciona o template de métrica com base no nome exato do motor."""
    for config in ENGINE_MAPPING.values():
        if engine_name in config["matches"]:
            return config["template"]
    return None


def get_metric_data(
    region, db_instance_id, template, period, hour_start, hour_stop, session
):
    cloudwatch = session.client("cloudwatch", region_name=region)
    template_path = os.path.join(WORK_DIR, template)
    with open(template_path, "r") as f:
        metric_query_str = f.read()
    # Substitui os placeholders ANTES de carregar o JSON
    metric_query_str = metric_query_str.replace("SED_INSTANCE_NAME", db_instance_id)
    metric_query_str = metric_query_str.replace("SED_PERIOD", str(period))
    metric_query = json.loads(metric_query_str)
    response = cloudwatch.get_metric_data(
        MetricDataQueries=metric_query, StartTime=hour_start, EndTime=hour_stop
    )
    return response


def send_otel(db_instance_id, value, metric_name, otel_attrs):
    try:
        value_int = int(round(float(value) * 100))
    except Exception as e:
        logging.warning(f"Valor inválido para métrica '{metric_name}': {value} ({e})")
        return

    debug_info = {
        "metric_name": metric_name,
        "db_instance_id": db_instance_id,
        "value_int": value_int,
        "scale": 100,
    }
    logging.debug(f"Enviando para OpenTelemetry: {debug_info}")

    try:
        attrs = {
            "key": metric_name,
            "scale": 100,
            "AGR": db_instance_id,
            "bu": BU,
            **otel_attrs,
        }

        bu_teste_rds_metrics.add(value_int, attributes=attrs)
        logging.info(
            f"Métrica enviada: AGR={db_instance_id}, key={metric_name}, valor={value_int}"
        )
    except Exception as e:
        logging.error(f"Falha ao enviar métrica para OTEL: {e}")


def send_percent_free_storage(
    db_instance_id, all_value, region, period, hour_start, hour_stop, session, otel_attrs
):
    allocated_gb = None
    for db in all_value["DBInstances"]:
        if db["DBInstanceIdentifier"] == db_instance_id:
            allocated_gb = db.get("AllocatedStorage", 0)
            break
    if allocated_gb is None:
        allocated_gb = 0
    cloudwatch = session.client("cloudwatch", region_name=region)
    response = cloudwatch.get_metric_statistics(
        Namespace="AWS/RDS",
        MetricName="FreeStorageSpace",
        Dimensions=[{"Name": "DBInstanceIdentifier", "Value": db_instance_id}],
        StartTime=hour_start,
        EndTime=hour_stop,
        Period=period,
        Statistics=["Maximum"],
    )
    datapoints = response.get("Datapoints", [])
    if datapoints:
        free_bytes = sorted(datapoints, key=lambda x: x["Timestamp"])[-1]["Maximum"]
        free_gb = free_bytes / 1024 / 1024 / 1024
        percent_free = (
            free_gb / allocated_gb * 100 if allocated_gb and allocated_gb > 0 else 0
        )
    else:
        percent_free = 0
    send_otel(db_instance_id, percent_free, "PercentFreeStorage", otel_attrs)


def send_percent_free_memory(
    db_instance_id, all_value, region, period, hour_start, hour_stop, session, otel_attrs
):
    # Carrega o mapeamento de memória de arquivo externo
    memory_map_path = os.path.join(
        os.path.dirname(__file__), "rds_instance_memory_map.json"
    )
    try:
        with open(memory_map_path, "r") as f:
            memory_map = json.load(f)
    except Exception as e:
        logging.error(f"Erro ao carregar o arquivo de memória: {e}")
        memory_map = {}

    instance_type = None
    for db in all_value["DBInstances"]:
        if db["DBInstanceIdentifier"] == db_instance_id:
            instance_type = db.get("DBInstanceClass", "").lower()
            break
    memory_gb = memory_map.get(instance_type, 0)
    cloudwatch = session.client("cloudwatch", region_name=region)
    response = cloudwatch.get_metric_statistics(
        Namespace="AWS/RDS",
        MetricName="FreeableMemory",
        Dimensions=[{"Name": "DBInstanceIdentifier", "Value": db_instance_id}],
        StartTime=hour_start,
        EndTime=hour_stop,
        Period=period,
        Statistics=["Maximum"],
    )
    datapoints = response.get("Datapoints", [])
    if datapoints and memory_gb:
        free_bytes = sorted(datapoints, key=lambda x: x["Timestamp"])[-1]["Maximum"]
        free_gb = free_bytes / 1024 / 1024 / 1024
        percent_used = (memory_gb - free_gb) / memory_gb * 100
    else:
        percent_used = 0
    send_otel(db_instance_id, percent_used, "PercentUsedMemory", otel_attrs)


def get_aws_session(account_name):
    """Cria uma sessão boto3, assumindo role se necessário."""
    env_role_var = f"{account_name.upper().replace('-', '_')}_ROLE"
    role_arn = os.getenv(env_role_var)

    if role_arn:
        logging.info(f"Variável de role '{env_role_var}' encontrada.")
        return assume_role(role_arn, f"rds-metrics-{account_name}")

    if account_name.lower() in ["none", ""]:
        logging.info("Nenhuma role especificada, usando credenciais locais.")
        return boto3.Session()

    logging.error(
        f"Account '{account_name}' não reconhecido e sem variável de role '{env_role_var}' configurada."
    )
    sys.exit(1)


def main():
    acquire_lock()
    try:
        parser = argparse.ArgumentParser(description="RDS Infra Monitoring")
        parser.add_argument("--account-name", required=True, help="Nome da conta AWS para monitorar.")
        parser.add_argument("--region", required=True, help="Região AWS das instâncias RDS.")
        parser.add_argument("--engine", required=True, help="Família do motor de banco de dados (ex: postgres, mysql).")
        parser.add_argument(
            "--period", type=int, default=300, help="Intervalo de coleta em segundos"
        )
        args = parser.parse_args()

        session = get_aws_session(args.account_name)

        hour_stop = datetime.now(timezone.utc)
        hour_start = hour_stop - timedelta(seconds=args.period)

        otel_attributes = {
            "ac_name": args.account_name,
            "region": args.region,
            "engine": args.engine,
        }

        all_instances_data = get_rds_instances(args.region, session)
        instance_list = filter_instances_by_engine(all_instances_data, args.engine)

        if not instance_list:
            logging.warning(
                f"Nenhuma instância encontrada para engine '{args.engine}' na região {args.region}."
            )
            sys.exit(0)

        for db_instance_id, engine_name in instance_list:
            logging.info(f"Processando instância: {db_instance_id} ({engine_name})")
            template = select_rds_template(engine_name)
            if not template:
                logging.warning(f"Engine '{engine_name}' não suportada para a instância {db_instance_id}. Pulando.")
                continue
            metric_data = get_metric_data(
                args.region,
                db_instance_id,
                template,
                args.period,
                hour_start,
                hour_stop,
                session,
            )
            for result in metric_data.get("MetricDataResults", []):
                for value in result.get("Values", []):
                    send_otel(db_instance_id, value, result.get("Label", ""), otel_attributes)

            send_percent_free_storage(
                db_instance_id,
                all_instances_data,
                args.region,
                args.period,
                hour_start,
                hour_stop,
                session,
                otel_attributes,
            )
            send_percent_free_memory(
                db_instance_id,
                all_instances_data,
                args.region,
                args.period,
                hour_start,
                hour_stop,
                session,
                otel_attributes,
            )
    finally:
        release_lock()


if __name__ == "__main__":
    main()
