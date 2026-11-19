# Conductor on Railway

A Railway template for [Conductor](https://github.com/conductor-oss/conductor) (Conductor OSS), the open-source durable workflow and agent orchestration engine that started at Netflix.

## What it deploys

| Service | Source | What it does |
|---|---|---|
| **Conductor** | `conductor/` in this repo (`conductoross/conductor:3.34.0`, pinned by digest) | Conductor server (REST and gRPC API on port 8080, private) and the Conductor UI behind nginx with HTTP basic auth on the public domain |
| **Elasticsearch** | `elasticsearch/` in this repo (`elasticsearch:8.19.25`, pinned by digest) | Search index for workflow and task executions (what the UI's search pages read). Security on, password generated, data on a volume |
| **Postgres** | Railway's PostgreSQL | Workflow and task state, metadata, queues, scheduler, large payloads |
| **Redis** | Railway's Redis | Distributed workflow execution lock |

## Variables

Conductor service:

- `CONDUCTOR_PASSWORD`: generated. Password for the UI and API (user `admin`, change with `CONDUCTOR_USERNAME`).
- `PG*`, `REDIS_*`, `ELASTICSEARCH_*`: reference variables to the other services. Nothing to fill in.

Elasticsearch service:

- `ELASTIC_PASSWORD`: generated password of the built-in `elastic` user.

## After deploy

Open the Conductor service's public URL, sign in as `admin` with the `CONDUCTOR_PASSWORD` from the service's Variables tab. Workers and SDK clients use `https://YOUR-DOMAIN/api` with the same basic-auth credentials, or the private `http://conductor.railway.internal:8080/api` from other services in the same project (no auth there).

## Updates

The services build from this repo. When the pinned Conductor or Elasticsearch version is bumped on `main`, Railway shows an "update available" notice in your project, and you choose when to apply it. Read `CHANGELOG.md` first.
