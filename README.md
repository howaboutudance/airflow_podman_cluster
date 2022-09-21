# Podman Airflow Development Cluster

This Project is designed to get a Airflow cluster up and going using podman
with metrics.

## Configuration

To get started, first create a virtualenv to startup so you can generate a
fernet encryption key.

```bash
python -m virtualenv .venv
source ./.venv/bin/activate
pip3 install -r requirements.txt
```

To start-up the cluster:

```
./scripts/podman-up.sh
```

Wait about 20 seconds and you can test accessing airflow via `http://localhost:8080/`

Other services have been loaded into the cluster

| Service        | Description                | URL |
|----------------|----------------------------|-----|
| Prometheus     | Prometheus Metrics         | `localhost:9090` |
| Celery Flower  | A dashboard of the Celery workers running in the background | `localhost:5555` |
| StatsD Exporter | Statsd prometheus exporter that is connected to the airflow instance | `localhost:9102` |

## Copyright & License
(C) 2022 Michael Penhallegon licensed under Apache-2.0

