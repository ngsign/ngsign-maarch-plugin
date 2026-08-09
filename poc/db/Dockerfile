# Self-seeding Maarch Courrier demo database for the NGSign POC.
# On first start (empty data volume), Postgres runs the scripts in
# /docker-entrypoint-initdb.d/ in alphabetical order: schema+demo data, then datestyle.
FROM postgres:14-alpine

# Loaded against POSTGRES_DB (= maarch_courrier, set via compose env)
COPY maarch_seed.sql   /docker-entrypoint-initdb.d/10_maarch_seed.sql
COPY 20_datestyle.sql  /docker-entrypoint-initdb.d/20_datestyle.sql
