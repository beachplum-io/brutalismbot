.PHONY: install cache mirror uninstall

install:
	docker-compose run --rm $@

cache:
	docker-compose run --rm $@

mirror:
	docker-compose run --rm $@

uninstall:
	docker-compose run --rm $@

clean:
	docker-compose down --volumes
