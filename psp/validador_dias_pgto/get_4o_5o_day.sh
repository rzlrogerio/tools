#!/bin/bash - 
#===============================================================================
#
#          FILE: get_5o_day.sh
# 
#         USAGE: ./get_5o_day.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Rogério de Araújo Rodrigues (), 
#  ORGANIZATION: 
#       CREATED: 08/05/2024 09:20
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Validar argumento de entrada
if [ $# -gt 0 ] && [ "$1" != "sabado-on" ] && [ "$1" != "sabado-off" ]; then
    echo "Erro: Primeiro argumento inválido '$1'." >&2
    echo "Uso: $0 [sabado-on|sabado-off] [feriados-on|feriados-off]" >&2
    exit 1
fi

if [ $# -gt 1 ] && [ "$2" != "feriados-on" ] && [ "$2" != "feriados-off" ]; then
    echo "Erro: Segundo argumento inválido '$2'." >&2
    echo "Uso: $0 [sabado-on|sabado-off] [feriados-on|feriados-off]" >&2
    exit 1
fi

# Variável de entrada para considerar sábado como dia útil ("sabado-on" ou "sabado-off")
CONSIDER_SATURDAY=${1:-"sabado-off"}

# Variável de entrada para considerar feriados ("feriados-on" ou "feriados-off")
HOLIDAY_MODE=${2:-"feriados-off"}

if [ "$CONSIDER_SATURDAY" = "sabado-on" ]; then
    echo "Configuração: Considerando o Sábado como dia útil para pagamentos."
else
    echo "Configuração: NÃO considerando o Sábado como dia útil para pagamentos."
fi

if [ "$HOLIDAY_MODE" = "feriados-on" ]; then
    echo "Configuração: Feriados Nacionais ATIVADOS (pula feriados)."
else
    echo "Configuração: Feriados Nacionais DESATIVADOS."
fi

HOLIDAYS_CACHE=""
CACHED_YEAR=""

HOLIDAY_FILE="$(dirname "$0")/feriados_2026.txt"

load_holidays_from_file() {
    local year=$1

    if [ "$year" != "2026" ]; then
        echo "Erro: suporte a feriados apenas para o ano de 2026. Atualize a base de feriados locais." >&2
        exit 1
    fi

    if [ ! -f "$HOLIDAY_FILE" ]; then
        echo "Erro: arquivo de feriados não encontrado: $HOLIDAY_FILE" >&2
        echo "Atualize a base local ou consulte o calendário oficial do governo." >&2
        exit 1
    fi

    grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' "$HOLIDAY_FILE" | awk '{print $1}' | tr '\n' ' '
}

# Verifica se a data é um feriado
is_holiday() {
    local date=$1
    if [ "$HOLIDAY_MODE" != "feriados-on" ]; then
        return 1 # false
    fi

    local year=$(date -d "$date" +%Y)

    # Preencher cache se necessário
    if [ "$year" != "$CACHED_YEAR" ]; then
        HOLIDAYS_CACHE=$(load_holidays_from_file "$year")
        CACHED_YEAR="$year"
    fi

    # Verificar se a data está no cache
    if [[ " $HOLIDAYS_CACHE " =~ " $date " ]]; then
        return 0 # true
    else
        return 1 # false
    fi
}

# Retorna o nome do dia da semana em português
get_day_name() {
    local date=$1
    local dow=$(date -d "$date" +%u)
    case $dow in
        1) echo "Segunda-feira" ;;
        2) echo "Terça-feira" ;;
        3) echo "Quarta-feira" ;;
        4) echo "Quinta-feira" ;;
        5) echo "Sexta-feira" ;;
        6) echo "Sábado" ;;
        7) echo "Domingo" ;;
    esac
}

# sábado ou domingo (fora)
is_weekday() {
    local date=$1

    # Se feriados estiver on e a data for feriado, não conta como dia útil
    if is_holiday "$date"; then
        return 1 # false
    fi

    # Obter o dia da semana (1=Segunda, 2=Terça, ..., 7=Domingo)
    local day_of_week=$(date -d "$date" +%u)
    
    if [ "$CONSIDER_SATURDAY" = "sabado-on" ]; then
        # Se considerar sábado, dias úteis são de segunda a sábado (1 a 6)
        if [ "$day_of_week" -lt 7 ]; then
            return 0  # true
        else
            return 1  # false
        fi
    else
        # Se não considerar sábado, dias úteis são de segunda a sexta (1 a 5)
        if [ "$day_of_week" -lt 6 ]; then
            return 0  # true
        else
            return 1  # false
        fi
    fi
}

# Função para encontrar o N-ésimo dia útil de um mês e ano específicos
find_nth_weekday() {
    local year=$1
    local month=$2
    local nth=$3
    local day=1
    local count=0

    # Loop pelos dias do mês
    while [ $count -lt $nth ]; do
        # Formatar a data como YYYY-MM-DD
        date=$(printf "%04d-%02d-%02d" $year $month $day)
        if is_weekday $date; then
            count=$((count + 1))
        fi
        day=$((day + 1))
    done

    # O dia anterior ao incremento acima é o N-ésimo dia útil
    day=$((day - 1))
    echo $(printf "%04d-%02d-%02d" $year $month $day)
}

# Loop pelos meses do ano atual
current_year=$(date +%Y)
for month in {1..12}; do
    fourth_weekday=$(find_nth_weekday $current_year $month 4)
    fifth_weekday=$(find_nth_weekday $current_year $month 5)
    fourth_day_name=$(get_day_name "$fourth_weekday")
    fifth_day_name=$(get_day_name "$fifth_weekday")

    echo "Para o mês $(printf "%02d" $month)/$current_year:"
    echo "  O 4º dia útil é $fourth_weekday ($fourth_day_name)"
    echo "  O 5º dia útil é $fifth_weekday ($fifth_day_name)"
done


