.PHONY: build up down logs re fclean status netinspect shell kafka kafka-connect mosquitto

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

status:
	docker compose ps

netinspect:
	docker network inspect mqttserver_mqtt_network

shell:
	docker compose exec kafka /bin/bash

kafka:
	docker compose up -d kafka

kafka-connect:
	docker compose up -d kafka-connect

mosquitto:
	docker compose up -d mqttserver-mosquitto-1

fclean:
	docker compose down --volumes --remove-orphans
	docker system prune -f
	docker volume prune -f
	docker network prune -f
	
re: fclean build up
