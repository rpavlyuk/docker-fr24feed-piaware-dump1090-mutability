#!/bin/bash

VERSION="1.0"
CONTAINER_NAME="docker.io/rpavlyuk/c7-fr24"

# Build docker container
docker build --rm -t $CONTAINER_NAME .
