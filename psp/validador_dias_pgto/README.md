# Validador de Dias Úteis para Pagamentos

Este diretório contém scripts que calculam o 4º e 5º dia útil do mês para pagamentos, considerando configurações de sábado e feriados.

## Arquivos principais

- `get_4o_5o_day.sh` — shell script que calcula o 4º e 5º dia útil do mês atual.
- `validador_data.py` — script Python com validação semelhante e interface do tipo `sabado-on`/`feriados-on`.
- `feriados_2026.txt` — base local de feriados de 2026 com data e descrição.
- `feriados_2026.md` — documentação legível dos feriados de 2026.
- `setup_venv.sh` — script para criar ambiente virtual Python.

## Uso

### Shell script

```bash
./get_4o_5o_day.sh sabado-on feriados-on
```

### Python

```bash
source .venv/bin/activate
python validador_data.py sabado-on feriados-on
```

## Observações

- O modo `feriados-on` utiliza o arquivo local `feriados_2026.txt`.
- O `sabado-on` considera sábado como dia útil.
