.PHONY: oauth posts dispatch mirror

oauth:
	docker-compose run --rm $@

posts:
	docker-compose run --rm -e MIN_TIME $@

dispatch:
	docker-compose run --rm $@

mirror:
	docker-compose run --rm $@

clean:
	docker-compose down --volumes
