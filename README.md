[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/conductor-1?utm_medium=integration&utm_source=button&utm_campaign=conductor)

# Conductor on Railway

A Railway template for [Conductor](https://github.com/conductor-oss/conductor) (Conductor OSS), the open-source durable workflow and agent orchestration engine that started at Netflix.

## What it deploys

| Service | Source | What it does |
|---|---|---|
| **Conductor** | `conductor/` in this repo (`conductoross/conductor:3.34.0`, pinned by digest) | Conductor server (REST and gRPC API on port 8080, private) and the Conductor UI behind nginx with HTTP basic auth on the public domain |
| **Elasticsearch** | `elasticsearch/` in this repo (`elasticsearch:8.19.25`, pinned by digest) | Search index for workflow and task executions (what the UI's search pages read). Security on, password generated, data on a volume |
| **Postgres** | Railway's PostgreSQL | Workflow and task state, metadata, queues, scheduler, large payloads |
| **Redis** | Railway's Redis | Distributed workflow execution lock |

Every stateful service has its own volume: Postgres and Redis (Railway's), Elasticsearch at `/usr/share/elasticsearch/data`, and Conductor at `/app/data` (files uploaded through Conductor's file storage API).

## Variables

The deploy form asks for nothing: every value is generated or a reference.

Conductor service:

- `CONDUCTOR_PASSWORD`: generated. Password for the UI and API, user `admin` (set `CONDUCTOR_USERNAME` to change the user name).
- `PORT`: `5000`, the nginx port behind the public domain. Don't set it to `8080`, the Conductor server's own port.
- `PG*`, `REDIS_*`, `ELASTICSEARCH_*`: reference variables to the other services.
- Optional, not in the template: `JAVA_OPTS` (default `-Xms256m -Xmx1g`), `CONDUCTOR_LOAD_SAMPLE=true` (loads upstream's kitchen-sink sample workflow), and AI provider keys such as `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` for Conductor's LLM tasks.

Elasticsearch service:

- `ELASTIC_PASSWORD`: generated password of the built-in `elastic` user. Conductor uses it through a reference.
- `PORT`: `9200`. Optional: `ES_JAVA_OPTS` (default `-Xms512m -Xmx512m`).

## After deploy

Open the Conductor service's public URL, sign in as `admin` with the `CONDUCTOR_PASSWORD` from the service's Variables tab. Workers and SDK clients use `https://YOUR-DOMAIN/api` with the same basic-auth credentials, or the private `http://conductor.railway.internal:8080/api` from other services in the same project (no auth there).

## Notes

- The first start takes a few minutes: Conductor waits for Postgres, Redis and a healthy Elasticsearch, then creates its tables and search indices.
- Conductor itself has no user accounts. The template protects the public URL with HTTP basic auth (one shared login); the private port 8080 has no auth, so only expose it inside the project.
- Elasticsearch is private (no public domain) and has security on. Only its cluster health answers without a password, for Railway's health check.

## Updates

The services build from this repo. When the pinned Conductor or Elasticsearch version is bumped on `main`, Railway shows an "update available" notice in your project, and you choose when to apply it. Read `CHANGELOG.md` first.
