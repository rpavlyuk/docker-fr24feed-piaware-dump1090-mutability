#!/bin/bash

docker -D run  \
	-p 8080:8080 -p 8754:8754 \
	--device=/dev/bus/usb:/dev/bus/usb \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
	-v /etc/ads-b/upintheair.json:/usr/lib/fr24/public_html/upintheair.json \
	-v /etc/ads-b/piaware.conf:/etc/piaware.conf \
	-v /etc/ads-b/config.js:/usr/lib/fr24/public_html/config.js \
	-v /etc/ads-b/fr24feed.ini:/etc/fr24feed.ini \
	docker.io/rpavlyuk/c7-fr24
