import boto3
from datetime import datetime, timedelta
import calendar
import os

_holidays_cache = {}

# Carrega feriados nacionais a partir de arquivo local e armazena em cache por ano
def get_holidays(year):
    if year not in _holidays_cache:
        file_path = os.path.join(os.path.dirname(__file__), "feriados_2026.txt")

        if not os.path.isfile(file_path):
            raise FileNotFoundError(
                f"Arquivo de feriados não encontrado: {file_path}. "
                "Atualize a base local ou consulte o calendário oficial do governo."
            )

        if year != 2026:
            raise ValueError(
                "Suporte local de feriados disponível apenas para 2026. "
                "Atualize a base de feriados para anos adicionais."
            )

        with open(file_path, "r", encoding="utf-8") as f:
            holidays = set()
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(None, 1)
                holidays.add(parts[0])
        _holidays_cache[year] = holidays

    return _holidays_cache[year]

# Função para verificar se um dia é útil
def is_weekday(date, consider_saturday="sabado-off", holiday_mode="feriados-off", holidays=None):
    if holiday_mode == "feriados-on" and holidays:
        date_str = date.strftime("%Y-%m-%d")
        if date_str in holidays:
            return False
            
    if consider_saturday == "sabado-on":
        return date.weekday() < 6  # Segunda a Sábado
    return date.weekday() < 5      # Segunda a Sexta

# Função para encontrar o N-ésimo dia útil de um mês e ano específicos
def find_nth_weekday(year, month, nth, consider_saturday="sabado-off", holiday_mode="feriados-off", holidays=None):
    day = 1
    count = 0
    
    while count < nth:
        current_date = datetime(year, month, day)
        if is_weekday(current_date, consider_saturday, holiday_mode, holidays):
            count += 1
        day += 1

    # O dia anterior ao incremento acima é o N-ésimo dia útil
    return current_date

# --- Funções agregadas de coreagem-pra-mais-metro.py ---
def is_business_day(day, consider_saturday="sabado-off", holiday_mode="feriados-off", holidays=None):
    if holiday_mode == "feriados-on" and holidays:
        day_str = day.strftime("%Y-%m-%d")
        if day_str in holidays:
            return False
            
    if consider_saturday == "sabado-on":
        return day.weekday() < 6
    return day.weekday() < 5

def get_nth_business_day(year, month, n, consider_saturday="sabado-off", holiday_mode="feriados-off", holidays=None):
    count = 0
    for i in range(1, calendar.monthrange(year, month)[1] + 1):
        day = datetime(year, month, i)
        if is_business_day(day, consider_saturday, holiday_mode, holidays):
            count += 1
        if count == n:
            return day
# ------------------------------------------------------

def lambda_handler(event, context):
    consider_saturday = "sabado-off"
    feriados_mode = "feriados-off"
    if event and isinstance(event, dict):
        consider_saturday = event.get('consider_saturday', 'sabado-off')
        feriados_mode = event.get('feriados_mode', 'feriados-off')

    if consider_saturday not in ['sabado-on', 'sabado-off']:
        raise ValueError(f"Argumento inválido: 'consider_saturday' deve ser 'sabado-on' ou 'sabado-off'. Recebido: '{consider_saturday}'")

    if feriados_mode not in ['feriados-on', 'feriados-off']:
        raise ValueError(f"Argumento inválido: 'feriados_mode' deve ser 'feriados-on' ou 'feriados-off'. Recebido: '{feriados_mode}'")

    today = datetime.today()

    holidays = None
    if feriados_mode == "feriados-on":
        holidays = get_holidays(today.year)

    # Mapeamento do dia da semana em português
    weekday_names = {
        0: "Segunda-feira",
        1: "Terça-feira",
        2: "Quarta-feira",
        3: "Quinta-feira",
        4: "Sexta-feira",
        5: "Sábado",
        6: "Domingo"
    }
    today_weekday_name = weekday_names[today.weekday()]

    # Verifica se hoje é o 4º, 5º ou 6º dia útil
    for nth in [4, 5, 6]:
        nth_weekday = find_nth_weekday(today.year, today.month, nth, consider_saturday, feriados_mode, holidays)
        if today.date() == nth_weekday.date():
            return {
                'status': 'Day skipped for recycling',
                'dia_da_semana': today_weekday_name
            }

    # Logica para executar a ação aqui
    # Exemplo: boto3 para listar e realizar a ação

    return {
        'status': 'Podemos executar a ação!',
        'dia_da_semana': today_weekday_name
    }


if __name__ == "__main__":
    import argparse
    import json
    import sys

    parser = argparse.ArgumentParser(
        description="Validador de dias úteis para o script validador_data.py"
    )
    parser.add_argument(
        "consider_saturday",
        nargs="?",
        choices=["sabado-on", "sabado-off"],
        default="sabado-off",
        help="Configuração para considerar sábado como dia útil"
    )
    parser.add_argument(
        "feriados_mode",
        nargs="?",
        choices=["feriados-on", "feriados-off"],
        default="feriados-off",
        help="Configuração para considerar feriados nacionais"
    )

    args = parser.parse_args()
    result = lambda_handler(
        {
            "consider_saturday": args.consider_saturday,
            "feriados_mode": args.feriados_mode,
        },
        None,
    )
    print(json.dumps(result, ensure_ascii=False))
    sys.exit(0)



