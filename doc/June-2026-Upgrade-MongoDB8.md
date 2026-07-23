## Upgrading from MongoDB 5.0 to 8.0

In June 2026, kobo-docker was updated to use MongoDB 8.
If you have not performed these steps, you must follow these one-time instructions to upgrade from MongoDB 5 to MongoDB 8. To do so you must upgrade to version 6, 7, and then 8 - you **CANNOT** skip versions when migrating.  This upgrade process does incur downtime until it is complete.

While the MongoDB version change is within kobo-docker, the commands shown below are for [kobo-install](https://github.com/kobotoolbox/kobo-install) and expected to be run in the directory containing kobo-install.

### Important note about Mongo 8 and linux incompatibility
As of July 2026, there is an incompatibility with Mongo 8 and Linux kernel 6.19+. See [this](https://jira.mongodb.org/browse/SERVER-121912) and [this](https://jira.mongodb.org/browse/SERVER-125742) mongodb JIRA card for details.

There is also a warning on the top of https://www.mongodb.com/docs/v8.0/release-notes/8.0/

If you receive this error:
```
msg":"MongoDB cannot start: Linux kernel versions 6.19 and newer has a known incompatibility with this version of MongoDB. See https://jira.mongodb.org/browse/SERVER-121912 for more information."
```
You can resolve it by adding this in your `docker-compose.backend.custom.yml` file:
```yaml
  mongo:
    environment:
      GLIBC_TUNABLES: "glibc.pthread.rseq=1"
```

Once this issue is fixed, you can remove this environment variable.

### Upgrading MongoDB

**Upgrading Mongo is easy and only requires several stops and starts**

1. Important: Before starting, back up your MongoDB data volumes. Upgrading between major versions can cause data loss if something goes wrong.

1. Upgrade to 6.0

    1. Stop `mongo` container

        ```shell
        user@computer:kobo-install$ python3 run.py -cb stop mongo
        ```

    1. Edit compose file `docker-compose.backend.yml` and change the mongo image to `mongo:6.0` (it should contain `mongo:8.0`)

        ```
        mongo:
          image: mongo:6.0
        ```

    1. Start the container:

        ```shell
        user@computer:kobo-install$ python3 run.py -cb up --force-recreate mongo -d
           ```

    1. Wait for MongoDB to be ready. You should see a "startup complete" message in the logs: `python3 run.py -cb logs mongo -f | grep "mongod startup complete"`

    1. From another terminal, enter the container using `python3 run.py --compose-backend exec mongo bash` and update compatibility version.
        For version 6.0: 
        ```shell
        root@mongo:/# mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" admin
        admin> db.adminCommand( { setFeatureCompatibilityVersion: "6.0" } )
        { "ok" : 1 }
        admin> exit
        bye
        root@mongo:/# exit
        ```

        For version 7.0/8.0 (change version accordingly):
        ```shell
        root@mongo:/# mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" admin
        admin> db.adminCommand( { setFeatureCompatibilityVersion: "7.0", confirm: true } )
        { "ok" : 1 }
        admin> exit
        bye
        root@mongo:/# exit
        ```

1. Upgrade to 7.0, 8.0

    Repeat the steps above for each version and replace the version accordingly.
    You **must** upgrade each version one by one.


### Tests

1. Test if upgrade is successful

    Start your containers as usual.

    ```shell
    user@computer:kobo-install$ python3 run.py
    ```

    Log into one of your user accounts and validate everything is working as expected.
