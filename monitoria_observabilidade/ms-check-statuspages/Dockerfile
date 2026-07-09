FROM python:3.12-slim 

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY app/monitors/ /app/monitors/
COPY app/monitor_multi_health.py /app/monitor_multi_health.py
COPY README.md /app/README.md

USER userapp

ENTRYPOINT ["python3", "/app/monitor_multi_health.py"]

