# kobo-docker
Future home of KoBo Toolbox's Docker configuration.

# Temporary setup procedure for server installations (e.g. UNHCR)
1. Configure [`envfile.txt`](./envfile.txt)
2. If faking a public server by manipulating `/etc/hosts`, configure the `extra_hosts` directives in [`docker-compose.server.yml`](./docker-compose.server.yml)
3. Make a `secrets` directory in the project root and copy the SSL certificate and key files to `secrets/ssl.crt` and `secrets/ssl.key` respectively.
4. Optionally clear previously persisted files: `sudo rm -rf .vols/ log/`
5. Optionally clear previously built containers: `docker-compose -f docker-compose.server.yml rm -f`
6. As a temporary workaround to avoid a race condition, manually initiate `kpi` database sync and migrations (quit with `CTRL+C` once UWSGI has started): `docker-compose -f docker-compose.server.yml run --rm kpi`
7. As a temporary workaround to avoid a race condition, manually initiate `dkobo` (yes, really) database sync and migrations, and initialize an admin user with credentials `kobo:kobo` (quit with `CTRL+C` once UWSGI has started): `docker-compose -f docker-compose.server.yml run --rm dkobo`
8. As a temporary workaround to avoid a race condition, manually initiate `kobocat` database sync and migrations (quit with `CTRL+C` once UWSGI has started): `docker-compose -f docker-compose.server.yml run --rm kobocat`
9. Start the server: `docker-compose -f docker-compose.server.yml up` (or with `up -d` to run in background)

# TODO
* Enketo Express authentication issue.
* KoBoCAT login redirect (e.g https://kf-local.kobotoolbox.org/accounts/login/?next=/kobocat/ -> https://kf-local.kobotoolbox.org/kobocat/ -> `404`)
* SMTP e-mail.
* Media files?
* Maps?
