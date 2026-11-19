# Conductor (server + UI) for the Railway template.
# Official image, pinned by version and digest. Bump both together.
FROM conductoross/conductor:3.34.0@sha256:0dbbe4a15bf0c59cfc4d53d10390ef4bbdf6313c2efed96db2ebb467b9ab470d

COPY --chmod=0755 start.sh /app/railway-start.sh

# Upstream's image uses ENTRYPOINT /bin/sh with CMD /app/startup.sh; this wrapper
# writes the Railway wiring (Postgres, Elasticsearch, Redis, basic auth) first.
ENTRYPOINT ["/bin/sh"]
CMD ["/app/railway-start.sh"]
