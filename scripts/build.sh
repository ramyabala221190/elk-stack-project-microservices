#!/bin/bash

export IMAGE_TAG=$(date +%Y%m%d%H%M%S)

# build
docker compose -p elk -f docker-compose.yml build

# login
docker login

# push
echo "Pushing docker image with tag ${IMAGE_TAG}"
docker login
docker push dockerenthusiast1992/my-logstash:${IMAGE_TAG}