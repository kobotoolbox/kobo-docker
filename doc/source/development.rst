Development
------------

Inside docker
===============

You can access any running container by doing::

    docker exec -it container_id /bin/bash

You can get any container id by doing::

    docker ps

Access the Python code and server
======================================

The Python code is usually located at /srv/src/.

You can create a superuser the usual way:

.. code-block:: bash

    ./manage.py createsuperuser

For Django, it is served using uwsgi. If you wish to use the dev server for debugging, kill uwsgi:

.. code-block:: bash

    sv stop wsgi  # stop the service (to avoid auto restart)
    killall -s INT uwsgi  # kill current instances

Then start the dev server. E.G, for kobocat:

.. code-block:: bash

    cd /srv/src/kobocat # go to the project dir
    python ./manage.py runserver 0.0.0.0:8000 # 0.0.0.0 so it listen to all interfaces

But nginx is configured to proxy to uswgi, so you need to enter the nginx docker image, and edit the config file to replace all uwsgi commands by regular proxy_pass.

E.G, for kobocat:

.. code-block:: bash

    vi /etc/nginx/conf.d/kobo_site_http.conf

Under::

    # KoBoCAT
    server {

Change all mention looking like::

    uwsgi_read_timeout 130;
    uwsgi_send_timeout 130;
    uwsgi_pass kobocat:8000;
    include /etc/nginx/uwsgi_params;

To code looking like::

    proxy_pass http://kobocat:8005; # do NOT add a / at the end
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr ;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for ;

And reload nginx conf:

.. code-block:: bash

    nginx -s reload

You can also edit any \*.tpl file in /etc/nginx/ and run sv restart nginx to rebuild /etc/nginx/conf.d/kobo_site_http.conf .

If you do that often, use a script.

E.G, save this code in /tmp/set_conf_to_dev.py:

.. code-block:: python


    import re, sys, os

    for path in sys.argv[1:]:
        print 'Replacing', path

        conf = open(path).read()


        res = re.sub(
        r"""
        ([\t ]+)(uwsgi_read_timeout\s+\d+;[\t ]*)\n
        ([\t ]+uwsgi_send_timeout\s+\d+;[\t ]*)\n
        ([\t ]+uwsgi_pass\s+(\w+):\s*(\d+);[\t ]*)\n
        ([\t ]+include [^;]+;[\t ]*)\n
        """,
        """
        \g<1> # Production settings (for uwsgi)
        #\g<1>\g<2>
        #\g<3>
        #\g<4>
        #\g<7>

        \g<1># Dev settings (for Django dev server)
        \g<1>proxy_pass http://\g<5>:\g<6>;
        \g<1>proxy_set_header Host $http_host;
        \g<1>proxy_set_header X-Real-IP $remote_addr ;
        \g<1>proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        """,
            conf,
            flags=re.VERBOSE|re.M
        )

        with open(sys.argv[1], 'w') as f:
            f.write(res)

    print('ok')


Then run:

.. code-block:: bash

    python /tmp/set_conf_to_dev.py /etc/nginx/file_you_want_to_edit1 /etc/nginx/file_you_want_to_edit2...


Stopping containers
======================

If you need to stop containers, and it doesn't work, try rebooting then stop them in a certain order:

1. web services;
2. psql/redis/rabbi;
3. mongo.

Or try stopping them with internet disabled.

