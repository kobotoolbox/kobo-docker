#!/bin/bash

# copyleft 2015 teodorescu.serban@gmail.com

if [ -z $EDITOR ]; then
  which mcedit > /dev/null
  if [ $? -eq 0 ]; then
    EDITOR=mcedit
  else
    which nano > /dev/null
    if [ $? -eq 0 ]; then
      EDITOR=mcedit
    else
      EDITOR=vi
    fi
  fi
fi

echo "Please customize the public vars."
echo "The prefix, http and https ports maybe?"
read -p "Press any key to start $EDITOR. " -n 1 -r
$EDITOR set_vars

echo "Creating docker-compose configuration file and env files..."
source set_vars
envsubst < common.tpl > common.yml
for f in $(ls env_*.tpl | sed -e 's/\.tpl$//'); do
    envsubst < $f.tpl > $f
    sed -i 's/%/$/' $f
done
echo "Done. Inspect it. If you see something not quite right, re run this script."

echo "You are ready to start the KOBO environment!"
