# Changelog

Each entry lists breaking changes first. Read it before you apply an update from Railway.

## 3.34.0 (2026-11-19)

First release of the template.

- Conductor server and UI `conductoross/conductor:3.34.0` (pinned by digest), behind nginx basic auth with a generated password.
- Elasticsearch `8.19.25` (pinned by digest) for workflow search, security on, generated password, own volume.
- Railway Postgres for workflow state, queues and the scheduler; Railway Redis for the workflow execution lock.
