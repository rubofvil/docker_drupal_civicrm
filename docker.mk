include .env

default: up

COMPOSER_ROOT ?= /var/www/html
DRUPAL_ROOT ?= /var/www/html/web
SUFFIX_CONTAINER ?= _civicrm
NAME_CONTAINER=$(PROJECT_NAME)$(SUFFIX_CONTAINER)
IP_CONTAINER=$(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(NAME_CONTAINER))


.PHONY: help
ifneq (,$(wildcard docker.mk))
help : docker.mk
	@sed -n 's/^##//p' $<
else
help : Makefile
	@sed -n 's/^##//p' $<
endif

.PHONY: up
up:
	@echo "Starting up containers for $(PROJECT_NAME)..."
	docker-compose pull
	docker-compose up -d --remove-orphans

.PHONY: mutagen
mutagen:
	mutagen-compose up

.PHONY: down
down: stop

.PHONY: start
start:
	@echo "Starting containers for $(PROJECT_NAME) from where you left off..."
	@docker-compose start

.PHONY: stop
stop:
	@echo "Stopping containers for $(PROJECT_NAME)..."
	@docker-compose stop

.PHONY: prune
prune:
	@echo "Removing containers for $(PROJECT_NAME)..."
	@docker-compose down -v $(filter-out $@,$(MAKECMDGOALS))

.PHONY: ps
ps:
	@docker ps --filter name='$(PROJECT_NAME)*'

.PHONY: shell
shell:
	docker exec -ti -e COLUMNS=$(shell tput cols) -e LINES=$(shell tput lines) $(shell docker ps --filter name='$(PROJECT_NAME)_$(or $(filter-out $@,$(MAKECMDGOALS)), 'php')' --format "{{ .ID }}") sh

.PHONY: composer
composer:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) $(filter-out $@,$(MAKECMDGOALS))

.PHONY: drush
drush:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush --uri=$(PROJECT_NAME).$(DOMAIN) -r $(DRUPAL_ROOT) $(filter-out $@,$(MAKECMDGOALS))

.PHONY: clean_database_test
clean_database_test:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin -e "DROP DATABASE IF EXISTS test; CREATE DATABASE test;" $(filter-out $@,$(MAKECMDGOALS))

.PHONY: phpunit_setup
phpunit_setup:
	rm -rf html/phpunit.xml
	cp phpunit.xml.dist html/phpunit.xml
	sed -r 's/name\=\"SIMPLETEST_BASE_URL\"\ value\=\"(.*)\"/name\=\"SIMPLETEST_BASE_URL\"\ value\=\"http\:\/\/$(IP_CONTAINER)\"/g' html/phpunit.xml
	sed -r 's/name\=\"BROWSERTEST_OUTPUT_BASE_URL\"\ value\=\"(.*)\"/name\=\"BROWSERTEST_OUTPUT_BASE_URL\"\ value\=\"http\:\/\/"$(PROJECT_NAME)\.localhost\"/g' html/phpunit.xml
	sed 's/ALIAS_SELENIUM/$(PROJECT_NAME)_selenium/g' html/phpunit.xml

.PHONY: phpunit
phpunit:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") sudo -u www-data /var/www/html/vendor/phpunit/phpunit/phpunit -v -c /var/www/html/phpunit.xml $(EXTRA)

.PHONY: clone_repo
clone_repo:
	rm -rf html
	git clone -b ${REPO_DRUPAL_TAG} ${REPO_DRUPAL} html
	docker-compose down && docker-compose up -d

.PHONY: install_drupal
install_drupal:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin -e "DROP DATABASE IF EXISTS drupal; CREATE DATABASE drupal;"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) site-install ${PROFILE} --db-url=mysql://root:admin@${PROJECT_NAME}_mysql:3306/drupal --account-pass=admin --uri=http://$(PROJECT_NAME).$(DOMAIN) -y

.PHONY: uninstall_drupal
uninstall_drupal:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin -e "DROP DATABASE IF EXISTS drupal;"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") rm -f $(DRUPAL_ROOT)/sites/default/settings.php
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") rm -f $(DRUPAL_ROOT)/sites/default/civicrm.settings.php
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") rm -rf $(DRUPAL_ROOT)/sites/default/files
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") mkdir files
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") sudo chown -R www-data:www-data $(DRUPAL_ROOT)

.PHONY: add_required_files_install
add_required_files_install:
	cp drupal_files_default/default.settings.php $(DRUPAL_ROOT)/sites/default/default.settings.php
	cp drupal_files_default/default.services.yml $(DRUPAL_ROOT)/sites/default/default.services.yml

.PHONY: set_permissions
set_permissions:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") sudo chown -R www-data:www-data $(DRUPAL_ROOT)

.PHONY: download_drupal_civicrm
download_drupal_civicrm:
	rm -rf html
	mkdir html
	git clone -b ${REPO_DRUPAL_CIVICRM_TAG} ${REPO_DRUPAL_CIVICRM} html
	docker-compose down && docker-compose up -d
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") composer install --working-dir=$(COMPOSER_ROOT)

.PHONY: logs
logs:
	@docker-compose logs -f $(filter-out $@,$(MAKECMDGOALS))

# https://stackoverflow.com/a/6273809/1826109
%:
	@: