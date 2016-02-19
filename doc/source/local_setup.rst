Local setup
--------------------------

Configuration
===============

Fill in the mandatory variables and, as needed, the optional variables in envfile.txt.

E.G:

.. code-block:: bash

    # Mandatory variables:
    PUBLIC_DOMAIN_NAME=kobotoolbox.org
    KOBOFORM_PUBLIC_SUBDOMAIN=kf-local
    KOBOCAT_PUBLIC_SUBDOMAIN=kc-local
    ENKETO_EXPRESS_PUBLIC_SUBDOMAIN=ee-local
    ENKETO_API_TOKEN=dev-token
    DJANGO_SECRET_KEY=xnq@yrgya$b27HJKLFHD798876894m2qtbwx3u7%n

You can generate a Django secret key `online <http://www.miniwebtool.com/django-secret-key-generator/>`_.

Make sure you don't have any previously persisted file (logs, database, static files, etc) from previous installs:

.. code-block:: bash

    # BE CAREFUL WITH THIS ONE, check the path twice as you are running rm with sudo
    sudo rm -rf .vols/ log/

Building and running docker images
===================================

Make sure you don't have container running, then clear previously built containers:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml rm -f

If you run into a error looking like::

    ERROR: client and server don't have same version (client : 1.21, server: 1.18)

Set the COMPOSE_API_VERSION environment variable to the matching server version. E.G:

.. code-block:: bash

    export COMPOSE_API_VERSION=1.18

To avoid having to type it everytime, you can add it to your .bashrc if you are using Linux/Mac.

Run:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml run --rm kpi

This will take some time on the first run, as it will download several GB worth of docker images.

This run only the "kpi" section of the file, which setup the files (static files, db files, etc) on the external volume for this container. --rm takes care of deleting the container after that.

Until you see something like::

    Feb 18 19:06:59 kpi syslog-ng[72]: syslog-ng starting up; version='3.5.3'

Then you can kill the process with CTRL+C.

Then We do the same other sections:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml run --rm dkobo

Until you see something like::

    Feb 18 19:08:02 dkobo syslog-ng[100]: syslog-ng starting up; version='3.5.3'

Then you can kill the process with CTRL+C.

Then run:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml run --rm kobocat

Until you see something like::

    [2016-02-18 14:09:47,538: WARNING/MainProcess] celery@kobocat ready.

Then you can kill the process with CTRL+C.

Finally start all images:

.. code-block:: bash

    docker-compose -f docker-compose.local.yml up

Ang go to::

    http://127.0.0.1:8001/

