#!/usr/bin/env bash

apt-get update && apt-get install vim -y
apt-get update && apt-get install libdbd-pg-perl -y
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/jfcoz/postgresqltuner/master/postgresqltuner.pl -P /root