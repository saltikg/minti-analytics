# minti_dbt

dbt Core project for building analytics models in the `analytics` schema from raw tables in the `main` schema.

## Activate

```bash
source /home/ubuntu/apps/dbt/.venv/bin/activate
source /home/ubuntu/apps/dbt/.env
export DBT_LOG_PATH=/home/ubuntu/apps/dbt/logs
cd /home/ubuntu/apps/dbt/minti_dbt
```

## Commands

```bash
dbt debug
dbt run
dbt test
dbt build
```

## Notes

- dbt profile file: `~/.dbt/profiles.yml`
- Project path: `/home/ubuntu/apps/dbt/minti_dbt`
- Logs path: `/home/ubuntu/apps/dbt/logs`
- Password is loaded from `DBT_ENV_SECRET_PG_PASSWORD` in `/home/ubuntu/apps/dbt/.env`
