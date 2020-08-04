Development
------------

Inside docker
===============

You can access any running container by doing::

    docker exec -it container_id /bin/bash

You can get any container id by doing::

    docker ps

Access the Python processes
======================================

The Python code is usually located at /srv/src/.

You can create a superuser the usual way:

.. code-block:: bash

    ./manage.py createsuperuser

.. warning::
   Because of some glitch in the url routing, you must NOT named you user admin, otherwise
   you won't be able to go to your account page.

For Django, it is served using uwsgi. If you wish to use the dev server for debugging, kill uwsgi:

.. code-block:: bash

    sv stop wsgi  # stop the service (to avoid auto restart)
    killall -s INT uwsgi  # kill current instances

Then start the dev server. E.G, for kobocat:

.. code-block:: bash

    cd /srv/src/kobocat # go to the project dir
    python ./manage.py runserver 0.0.0.0:8001 # 0.0.0.0 so it listen to all interfaces

By default nginx is configured to proxy requests to uswsgi, but you now run the dev server so you need to set the NGINX_DEBUG_kobocat env var to True. You can do in your compose file "environment" sub-section.

You can also run them all at once:

.. code-block:: bash

  sv stop wsgi && killall -s INT uwsgi && cd /srv/src/kobocat && python ./manage.py runserver 0.0.0.0:8001

E.g, for kobocat edit docker-compose.local.yml, go to the "nginx" section and then:

.. code-block:: yml

  environment:
    - NGINX_DEBUG_kobocat=True


Access the Python code
======================================

Clone the code you wish to access, and map it in the "volumes" section of compose config file:

  volumes:
    - "/path/to/code/on/you/machine/:/path/to/code/in/the/container"

Your directory will override the container's directory, and you can edit the files
on your machine while the containers use them.

Stopping containers
======================

If you need to stop containers, and it doesn't work, try rebooting then stop them in a certain order:

1. web services;
2. psql/redis/rabbi;
3. mongo.

Or try stopping them with internet disabled.

