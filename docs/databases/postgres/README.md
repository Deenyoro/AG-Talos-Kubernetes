## Postgres databases

If an application uses Postgres and we use cloudnative-pg, we can use init-containers which have a separate secret containing
the postgres (aka root) users password as well as the new database users.

Example of how this is done can be found at kubernetes/apps/librechat/hr.yaml as it uses an init-container for this purpose.

The ENV variables the postgres-init container requires:
- INIT_POSTGRES_DBNAME
- INIT_POSTGRES_HOST
- INIT_POSTGRES_USER
- INIT_POSTGRES_PASS
- INIT_POSTGRES_SUPER_PASS
