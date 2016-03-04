Local setup
--------------------------

Configuration
===============

Fill in the mandatory variables and, as needed, the optional variables in envfile.local.txt.

E.G:

.. code-block:: bash

    # Mandatory variables:
    HOST_ADDRESS=172.17.0.1
    KPI_PUBLIC_PORT=8000
    KOBOCAT_PUBLIC_PORT=8001
    ENKETO_EXPRESS_PUBLIC_PORT=8005
    ENKETO_API_TOKEN=a
    DJANGO_SECRET_KEY=a


Building and running docker images
===================================

First, you run into a error looking like::

    ERROR: client and server don't have same version (client : 1.21, server: 1.18)

Set the COMPOSE_API_VERSION environment variable to the matching server version. E.G:

.. code-block:: bash

    export COMPOSE_API_VERSION=1.18

To avoid having to type it everytime, you can add it to your .bashrc if you are using Linux/Mac.

Make sure you don't have any previously images/containers/volumes from previous build.

A very radical way to get a clean state is:

.. code-block:: bash

    docker stop $(docker ps -a -q) # stop all containers
    docker rm -f $(docker ps -qa) # remove all containers
    docker volume rm $(docker volume ls -q) # remove all volumes
    docker rmi $(docker images -q)

This removes ALL volumes, containers and images on your system.

If you want more granularity, you can try in the kobo-docker repo:

.. code-block:: bash

    # clear previously built containers this configuration file
    docker-compose -f docker-compose.local.yml rm -f
    # remove volumes for this repo
    sudo rm -rf .vols/ log/

But be sure you cleared everything related to docker-compose.local.yml.

Now pull and build the images:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml pull
    docker-compose -f docker-compose.local.yml build

This will take some time on the first run, as it will download several GB worth of docker images.

Finally start all images:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml up

Ang go to::


    http://172.17.0.1:8000/

You may login as::

    username: kobo
    password: kobo