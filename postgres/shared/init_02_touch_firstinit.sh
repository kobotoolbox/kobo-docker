#!/usr/bin/env bash

# Touch this file to know if container starts for the first time.
echo date > $POSTGRES_DATA_DIR/.first_run