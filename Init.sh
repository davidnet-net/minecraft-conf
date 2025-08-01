#!/bin/bash

# Load Environment variables
source .env
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

echo "Waiting for restic to init... Zzzzzz slow."

restic init

echo "Inited succesfully."