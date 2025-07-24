.PHONY: build up down logs re fclean

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

fclean:
	docker-compose down --volumes --remove-orphans
	docker system prune -f
	docker volume prune -f
	docker network prune -f
	
re: fclean build up
