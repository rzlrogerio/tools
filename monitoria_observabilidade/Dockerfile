# Use uma imagem base oficial e leve do Python
FROM python:3.8-slim-buster

# Define variáveis de ambiente para otimizar a execução em contêineres
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Define o diretório de trabalho dentro do contêiner
WORKDIR /app

# Copia o arquivo de dependências e instala os pacotes
# Isso é feito em uma camada separada para aproveitar o cache do Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Cria um usuário não-root para executar a aplicação por segurança
RUN useradd -m appuser

# Copia o código da aplicação e os templates para o diretório de trabalho
COPY get_rds_status_infra.py .
COPY get-rds-status-infra-*.json .
COPY rds_instance_memory_map.json .

# Muda para o usuário não-root
USER appuser

# Define o comando padrão para executar a aplicação
ENTRYPOINT ["python3", "./get_rds_status_infra.py"]
