# DO NOT attempt to use this code unless your database was created with Postgres 9.5!

# WARNING
If you started running KoBo Toolbox using a version of `kobo-docker` from before to [2016.10.13](https://github.com/kobotoolbox/kobo-docker/commit/316b1464c86e2c447ca88c10d383662b4f2e4ac6), actions that recreate the `kobocat` container (including `docker-compose up ...` under some circumstances) will result in losing access to user media files (e.g. responses to photo questions). Safely stored media files can be found in `kobo-docker/.vols/kobocat_media_uploads/`.

Files that were not safely stored can be found inside Docker volumes as well as in your current and any previous `kobocat` containers. One quick way of finding these is directly searching the Docker root directory. The root directory can be found by running `docker info` and looking for the "Docker Root Dir" entry (not to be confused with the storage driver's plain "Root Dir").

Once this is noted, you can `docker-compose stop` and search for potentially-missed media attachment directories with something like `sudo find ${YOUR_DOCKER_ROOT_DIR}/ -name attachments`. These attachment directories will be of the format `.../${SOME_KOBO_USER}/attachments` and you will want to back up each entire KoBo user's directory (the parent of the `attachments` directory) for safe keeping, then move/merge them under `.vols/kobocat_media_uploads/`, creating that directory if it doesn't exist and taking care not to overwrite any newer files present there if it does exist. Once this is done, clear out the old container and any attached volumes with `docker-compose rm -v kobocat`, then `git pull` the latest `kobo-docker` code, `docker-compose pull` the latest images for `kobocat` and the rest, and your media files will be safely stored from there on.

## kobo-docker

`kobo-docker` is used to run a copy of the [KoBo Toolbox](http://www.kobotoolbox.org) survey data collection platform on a machine of your choosing. It relies on [Docker](https://docker.com) to separate the different parts of KoBo into different containers (which can be thought of as lighter-weight virtual machines) and [Docker Compose](https://docs.docker.com/compose/) to configure, run, and connect those containers. 
Below is a diagram (made with [Lucidchart](lucidchart.com)) of the containers that make up a running `kobo-docker` system and their connections. 

![Container diagram](./doc/Container_diagram.png)

## Load balancing and redundancy 

The main goal of this branch is to make applications containers aka `frontends` run on one host (`KoBoCat`, `KPI`, `Enketo Express`) and make databases containers aka `backends` (`PostgreSQL`, `MongoDB`, `RabbitMQ`, `redis`) run on another.

In `kobo-docker` master branch, each container communicate to each other through docker internal network and `link` property. Even if `KoBoCat`, `KPI`, `Enketo Express` on the same instance still communicate the same way, they now use domain names (or IP addresses) to communicate with `backends`. It allows `frontends` to be behind a load-balancer and to be redundant. 

### To-Do
`Backends` are not redundant yet except `PostgreSQL` which is configured in Master/Slave mode. Slave is a real-time read-only replica.

Below is another diagram (made with [Lucidchart](lucidchart.com)) of the containers that make up a running `kobo-docker` redundant system and their connections. 
   
_NB: The diagram is based on AWS infrastructure, but it's not required to host your environment there._

![Container diagram](./doc/aws-diagram.svg)




## Setup procedure:

1. We assume that secure (**HTTPS**) communications are used when using this branch. All communications must be secured (**HTTPS**) between users and the load-balancer but all communication between load-balancer and `frontends` must be on port 80 (**HTTP**). TLS/SSL certificate must be installed on load-balancer. It avoids to install if on `frontends` which can be started/stopped/terminated on-demand.  
If **HTTP** setup is needed, please read below for instructions.

2. Clone this repository, retaining the directory name `kobo-docker`.

3. Update to `ocha_aws` branch.

4. [Install Docker CE](https://docs.docker.com/compose/install/). Linux users, [install Docker Compose](https://docs.docker.com/compose/install/#install-compose) too which is not part of Docker CE.

5. Pull the latest images from Docker Hub: `docker-compose pull`. **Note:** Pulling updated images doesn't remove the old ones, so if your drive is filling up, try removing outdated images with e.g. `docker rmi`.

6. Copy `deployments` folder and paste it at the same level of `kobo-docker` folder. Rename it to `kobo-deployments`. There is also another alternative. You can edit all `docker-compose*.yml` files instead, then search and replace `../kobo-deployments` to the path you want.

7. Edit the appropriate environment files found in [`kobo-deployments/`](./deployments), filling in **all** mandatory variables, and optional variables as needed.  
**Don't forget to replace `domain.name` by your domain name.**

8. Optionally enable additional settings for your Google Analytics token, S3 bucket, e-mail settings, etc. by editing the files in [`envfiles/`](./envfiles).

9. Build any images you've chosen to manually override: `docker-compose build`.

10. Start servers:
    
	1. _Frontend server:_  
	`docker-compose -f docker-compose.frontend.yml up -d`  
	2. _Master backend server:_ `docker-compose -f docker-compose.backend.master.yml up -d` 
	3. _Slave backend server:_ `docker-compose -f docker-compose.backend.slave.yml up -d` 
	
	The `-d` option makes docker run in the background.  
	**Master and Slave backends MUST NOT be on the same host because they expose same ports. An error will occur.**
	
12. Container output can be followed with `docker-compose -f docker-compose*.yml logs -f`.  
For an individual container, logs can be followed by using the container name from your `docker-compose*.yml` with e.g. `docker-compose -f docker-compose.frontend.yml logs -f enketo_express`.

### Insecure (HTTP) setup
Docker-compose allows to compose files to be overriden. This feature can be used to use an insecure environment. Starting the frontend server can be done with this command: `docker-compose -f docker-compose.frontend.yml -f docker-compose.http.override.yml up -d` where `docker-compose.http.override.yml` would look like this:

```
# For public, HTTP servers.
version: '3'

services:
  kobocat:
    environment:
      - ENKETO_PROTOCOL=http
      - PUBLIC_REQUEST_SCHEME=http

  kpi:
    environment:
      - PUBLIC_REQUEST_SCHEME=http
      - SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO, $${PUBLIC_REQUEST_SCHEME}

  nginx:
    environment:
      - PUBLIC_REQUEST_SCHEME=http
      - TEMPLATED_VAR_REFS=$${PUBLIC_DOMAIN_NAME} $${KOBOFORM_PUBLIC_SUBDOMAIN} $${KOBOCAT_PUBLIC_SUBDOMAIN} $${ENKETO_EXPRESS_PUBLIC_SUBDOMAIN}
```

# Backups
**POSTGRES AUTOMATIC BACKUP IS CURRENTLY UNAVAILABLE**  

Automatic, periodic backups of KoBoCAT media, MongoDB, and Postgres can be individually enabled by uncommenting (and optionally customizing) the `*_BACKUP_SCHEDULE` variables in your `envfile`. When enabled, timestamped backups will be placed in `backups/kobocat`, `backups/mongo`, and `backups/postgres`, respectively. Redis backups are currently not generated, but the `redis_main` DB file is updated every 5 minutes and can always be found in `.vols/redis_main_data/`.

Backups can also be manually triggered when `kobo-docker` is running by executing the the following commands:
```
docker exec -it kobodocker_kobocat_1 /srv/src/kobocat/docker/backup_media.bash
docker exec -it kobodocker_mongo_1 /srv/backup_mongo.bash
docker exec -it kobodocker_postgres_1 /srv/backup_postgres.bash
```

## Troubleshooting

### Basic troubleshooting
You can confirm that your containers are running with `docker ps`. To inspect the log output from the containers, execute `docker-compose logs -f` or for a specific container use e.g. `docker-compose logs -f redis_main`.

The documentation for Docker can be found at https://docs.docker.com.

### Django debugging
Developers can use [PyDev](http://www.pydev.org/)'s [remote, graphical Python debugger](http://www.pydev.org/manual_adv_remote_debugger.html) to debug Python/Django code. To enable for the `kpi` container:

1. Specify the mapping(s) between target Python source/library paths on the debugging machine to the locations of those files/directories inside the container by customizing and uncommenting the `KPI_PATH_FROM_ECLIPSE_TO_PYTHON_PAIRS` variable in [`envfiles/kpi.txt`](./envfiles/kpi.txt).
2. Share the source directory of the PyDev remote debugger plugin into the container by customizing (taking care to note the actual location of the version-numbered directory) and uncommenting the relevant `volumes` entry in your `docker-compose.yml`.
3. To ensure PyDev shows you the same version of the code as is being run in the container, share your live version of any target Python source/library files/directories into the container by customizing and uncommenting the relevant `volumes` entry in your `docker-compose.yml`.
4. Start the PyDev remote debugger server and ensure that no firewall or other settings will prevent the containers from connecting to your debugging machine at the reported port.
5. Breakpoints can be inserted with e.g. `import pydevd; pydevd.settrace('${DEBUGGING_MACHINE_IP}')`.

Remote debugging in the `kobocat` container can be accomplished in a similar manner.


# Redis performance
Please take a look at https://www.techandme.se/performance-tips-for-redis-cache-server/
to get rid of Warning message when starting redis containers
