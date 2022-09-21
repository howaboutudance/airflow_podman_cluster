#!/bin/bash

set +x

NETWORK_NAME=airflow_network
POSTGRES_URI=airflow:airflow@postgres.dns.podman/airflow
POSTGRES_DB_URI=postgresql+psycopg2://${POSTGRES_URI}
POSTGRE_CELERY_URI=db+postgresql://${POSTGRES_URI}
REDIS_URI=redis://:@redis.dns.podman:6379/0
FERNET_KEY=$(python scripts/fernet_generate.py)

podman network create ${NETWORK_NAME}

#TODO: create postgresql server
podman pod create \
    --network=${NETWORK_NAME} \
    -n postgres \
    -p 5432:5432

podman run -dt --pod postgres \
    -e POSTGRES_PASSWORD=airflow \
    -e POSTGRES_USER=airflow \
    -e POSTGRES_DB=airflow \
    --health-cmd="['CMD', 'pg_isready', '-U', 'airflow']" \
    --health-interval=5s \
    --health-retries=5 \
    docker.io/postgres

# TODO: create podman pod and container for redis
podman pod create \
    --network=${NETWORK_NAME} \
    -n redis \
    -p 6379:6379

podman run -dt --pod redis \
    --health-cmd="['CMD', 'redis-cli', 'ping']" \
    --health-interval=5s \
    --health-retries=50 \
    docker.io/redis

# sleep to let db to startup
sleep 5 &&

podman pod create \
    --network=${NETWORK_NAME} \
    -n airflow-init

podman run -d --pod airflow-init \
    -e AIRFLOW_CORE_EXECUTOR=CeleryExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${POSTGRES_DB_URI} \
    -e AIRFLOW__CELERY__RESULT_BACKEND=${POSTGRE_CELERY_URI} \
    -e AIRFLOW__CELERY__BROKER_URL=${REDIS_URI} \
    -e AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY} \
    -e AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION='true' \
    -e AIRFLOW__CORE__LOAD_EXMAPLES='false' \
    -e AIRFLOW__API__AUTH_BACKENDS='airflow.api.auth.backend.basic_auth' \
    -e _PIP_ADDITIONAL_REQUIREMENTS="apache-airflow[statsd]" \
    -v ./src/dags:/opt/airflow/dags:z \
    -v ./scripts/config/airflow/plugins:/opt/airflow/plugins:z \
    --tmpfs /opt/airflow/logs:rw,size=787448k,mode=1777 \
    docker.io/apache/airflow \
    bash -c \
    "airflow db init && airflow users create  --firstname admin  --lastname admin  --email admin  --password admin  --username admin  --role Admin"

# sleep to let db init run -- replace with to when podman status init finishes
 sleep 15 &&

 podman pod create \
     --network=${NETWORK_NAME} \
     -n airflow-scheduler

#TODO: add health  check and retry 
 podman run -d --pod airflow-scheduler \
    -e AIRFLOW_CORE_EXECUTOR=CeleryExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${POSTGRES_DB_URI} \
    -e AIRFLOW__CELERY__RESULT_BACKEND=${POSTGRE_CELERY_URI} \
    -e AIRFLOW__CELERY__BROKER_URL=${REDIS_URI} \
    -e AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY} \
    -e AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION='true' \
    -e AIRFLOW__CORE__LOAD_EXMAPLES='false' \
    -e AIRFLOW__API__AUTH_BACKENDS='airflow.api.auth.backend.basic_auth' \
    -e _PIP_ADDITIONAL_REQUIREMENTS="apache-airflow[statsd]" \
    -v ./src/dags:/opt/airflow/dags:z \
    -v ./src/airflow.cfg:/opt/airflow/airflow.cfg:z \
    -v ./scripts/config/airflow/plugins:/opt/airflow/plugins:z \
    --tmpfs /opt/airflow/logs:rw,size=787448k,mode=1777 \
     docker.io/apache/airflow \
     airflow scheduler

podman pod create \
    --network=${NETWORK_NAME} \
    -n airflow-ui \
    -p 8080:8080 \

podman run -d --pod airflow-ui \
    -e AIRFLOW_CORE_EXECUTOR=CeleryExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${POSTGRES_DB_URI} \
    -e AIRFLOW__CELERY__RESULT_BACKEND=${POSTGRE_CELERY_URI} \
    -e AIRFLOW__CELERY__BROKER_URL=${REDIS_URI} \
    -e AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY} \
    -e AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION='true' \
    -e AIRFLOW__CORE__LOAD_EXAMPLES=False \
    -e AIRFLOW__API__AUTH_BACKENDS='airflow.api.auth.backend.basic_auth' \
    -e AIRFLOW__WEBSERVER__RBAC=False \
    -e _PIP_ADDITIONAL_REQUIREMENTS="apache-airflow[statsd]" \
    -v ./src/dags:/opt/airflow/dags:z \
    -v ./src/airflow.cfg:/opt/airflow/airflow.cfg:z \
    -v ./scripts/config/airflow/plugins:/opt/airflow/plugins:z \
    --tmpfs /opt/airflow/logs:rw,size=787448k,mode=1777 \
    --health-cmd="['CMD', 'curl', '--fail', 'http://localhost:8080/health']" \
    --health-interval=10s \
    --health-retries=5 \
    docker.io/apache/airflow \
    airflow webserver

podman pod create \
    --network=${NETWORK_NAME} \
    -n airflow-worker-1

podman run -d --pod airflow-worker-1 \
    -e AIRFLOW_CORE_EXECUTOR=CeleryExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${POSTGRES_DB_URI} \
    -e AIRFLOW__CELERY__RESULT_BACKEND=${POSTGRE_CELERY_URI} \
    -e AIRFLOW__CELERY__BROKER_URL=${REDIS_URI} \
    -e AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY} \
    -e AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION='true' \
    -e AIRFLOW__CORE__LOAD_EXMAPLES='false' \
    -e AIRFLOW__API__AUTH_BACKENDS='airflow.api.auth.backend.basic_auth' \
    -e AIRFLOW__WEBSERVER__RBAC=False \
    -e _PIP_ADDITIONAL_REQUIREMENTS="apache-airflow[statsd]" \
    -v ./src/dags:/opt/airflow/dags:z \
    -v ./src/airflow.cfg:/opt/airflow/airflow.cfg:z \
    -v ./scripts/config/airflow/plugins:/opt/airflow/plugins:z \
    --tmpfs /opt/airflow/logs:rw,size=787448k,mode=1777 \
    docker.io/apache/airflow \
    celery worker

podman pod create \
    --network=${NETWORK_NAME} \
    -n celery-flower \
    -p 5555:5555

podman run -d --pod celery-flower \
    -e AIRFLOW_CORE_EXECUTOR=CeleryExecutor \
    -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${POSTGRES_DB_URI} \
    -e AIRFLOW__CELERY__RESULT_BACKEND=${POSTGRE_CELERY_URI} \
    -e AIRFLOW__CELERY__BROKER_URL=${REDIS_URI} \
    -e AIRFLOW__CORE__FERNET_KEY=${FERNET_KEY} \
    -e AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION='true' \
    -e AIRFLOW__CORE__LOAD_EXMAPLES='false' \
    -e AIRFLOW__API__AUTH_BACKENDS='airflow.api.auth.backend.basic_auth' \
    -e AIRFLOW__WEBSERVER__RBAC=False \
    -e _PIP_ADDITIONAL_REQUIREMENTS="apache-airflow[statsd]" \
    -v ./src/dags:/opt/airflow/dags:z \
    -v ./src/airflow.cfg:/opt/airflow/airflow.cfg:z \
    -v ./scripts/config/airflow/plugins:/opt/airflow/plugins:z \
    --tmpfs /opt/airflow/logs:rw,size=787448k,mode=1777 \
    docker.io/apache/airflow \
    celery flower

podman pod create \
    --network=${NETWORK_NAME} \
    -n statsd_export \
    -p 9102:9102 \
    -p 9125:9125 \
    -p 9125:9125/udp \
    -p 9090:9090

podman run -d --pod statsd_export \
    docker.io/prom/statsd-exporter

podman run -d --pod statsd_export \
    -v ./scripts/prometheus.yml:/etc/prometheus/prometheus.yml:z \
    prom/prometheus