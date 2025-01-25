#!/bin/bash
CONTAINER_NAME=$(<"servername.txt")
docker exec -it $CONTAINER_NAME bash
