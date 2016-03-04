Overview
--------------------------

Key components
==============

The kobo toolbox is distributed as a group of docker images:

- rabbit: rabbit MQ broken. Used for queuing background tasks.
- psql: PostGres Database. Use to store geographic data.
- mongo: Mongo Database. Use to store data collected from form.
- kobocat: code for the form data backend: collection, processing, export, etc.
- kpi: code for the GUI to build form (alias koboform).
- nginx: nginx server serving static files and proxing requests to other services.
- enketo_express: service use to display the forms on various UI.
- redis_main: enkeko redis.
- redis_cache: redis used for caching.

We use docker compose to orchestrate all images, all configuration going to docker-compose.*.yml files.

A lot of the configuration is tweakable using env variable listed in template files.

.. warning::
   Setuping the whole kobo toolbox can take some time and require an good internet connection as
   it needs to download several GB worth of docker images.