Installing dependancies
--------------------------

Docker config and images
========================

To install the entiere Kobo environment, you need git, docker and docker compose.

On Ubuntu 14.04, you can install these dependancies this way:

.. code-block:: bash

    # install git (to get the code)
    #         pip (to install docker-compose)
    #         docker (to run the virtual machines)
    sudo apt-get install docker.io python-pip git # install docker, pip and git
    # some linux distributions provide the docker.io instead of docker but
    # all tutorials use docker, so making a alias
    sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker
    # install docker compose (to orchestrate virtual machines)
    sudo pip install docker-compose

Add yourself to the "docker" group so you don't have to use sudo for every docker command:

.. code-block:: bash

    sudo usermod -aG docker $USER

You need to login and logout for this to take effect.


Then you must clone the `kobo-docker repository <https://github.com/kobotoolbox/kobo-docker>`_:

.. code-block:: bash

    git clone https://github.com/kobotoolbox/kobo-docker.git
    cd kobo-docker

Troubleshoutting
================

You should check docker is running:

.. code-block:: bash

    ps aux | grep docker

If it's not, try to start it manually to get some error feedback:

.. code-block:: bash

    docker daemon

If you ever get an error such as::

    Error starting daemon: Error initializing network controller: Error creating default "bridge" network: failed to parse pool request for address space "LocalDefault" pool "" subpool "": could not find an available predefined network

It may be due to another sotfware using the bridge network as well. Try to disable your VPN or virtual machine bridges to see if the error disapear.