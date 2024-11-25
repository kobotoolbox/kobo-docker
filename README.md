# Kobo Docker

kobo-docker runs [KoboToolbox](http://www.kobotoolbox.org) survey data collection platform, using [Docker Compose](https://docker.com).
kobo-docker may be used for development and single server production deployments.

See general documentation at [support.kobotoolbox.org](https://support.kobotoolbox.org/kobo_your_servers.html).

## Run KoboToolbox all-in-one

## Run KoboToolbox with your own databases

`docker compose -f docker-compose.external-databases.yml up`

## Developing KoboToolbox

### First run

1. Build `docker compose build --pull`
2. Start postgres `docker compose up postgres` this ensures it has time to initialize
3. Run Django database migrations `docker compose run --rm kpi scripts/migrate.sh`
4. Make user `docker compose run --rm kpi ./manage.py createsuperuser`
5. Edit `/etc/hosts` and add `127.0.0.1 kf.kobo.local ee.kobo.local`
6. Run `npm i` in the kpi directory.
