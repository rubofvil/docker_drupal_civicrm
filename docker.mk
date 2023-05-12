include .env

default: up

COMPOSER_ROOT ?= /var/www/html
DRUPAL_ROOT ?= /var/www/html/web

## help	:	Print commands help.
.PHONY: help
ifneq (,$(wildcard docker.mk))
help : docker.mk
	@sed -n 's/^##//p' $<
else
help : Makefile
	@sed -n 's/^##//p' $<
endif

## up	:	Start up containers.
.PHONY: up
up:
	@echo "Starting up containers for $(PROJECT_NAME)..."
	docker-compose pull
	docker-compose up -d --remove-orphans

.PHONY: mutagen
mutagen:
	mutagen-compose up

## down	:	Stop containers.
.PHONY: down
down: stop

## start	:	Start containers without updating.
.PHONY: start
start:
	@echo "Starting containers for $(PROJECT_NAME) from where you left off..."
	@docker-compose start

## stop	:	Stop containers.
.PHONY: stop
stop:
	@echo "Stopping containers for $(PROJECT_NAME)..."
	@docker-compose stop

## prune	:	Remove containers and their volumes.
##		You can optionally pass an argument with the service name to prune single container
##		prune mariadb	: Prune `mariadb` container and remove its volumes.
##		prune mariadb solr	: Prune `mariadb` and `solr` containers and remove their volumes.
.PHONY: prune
prune:
	@echo "Removing containers for $(PROJECT_NAME)..."
	@docker-compose down -v $(filter-out $@,$(MAKECMDGOALS))

## ps	:	List running containers.
.PHONY: ps
ps:
	@docker ps --filter name='$(PROJECT_NAME)*'

## shell	:	Access `php` container via shell.
##		You can optionally pass an argument with a service name to open a shell on the specified container
.PHONY: shell
shell:
	docker exec -ti -e COLUMNS=$(shell tput cols) -e LINES=$(shell tput lines) $(shell docker ps --filter name='$(PROJECT_NAME)_$(or $(filter-out $@,$(MAKECMDGOALS)), 'php')' --format "{{ .ID }}") sh

## composer	:	Executes `composer` command in a specified `COMPOSER_ROOT` directory (default is `/var/www/html`).
##		To use "--flag" arguments include them in quotation marks.
##		For example: make composer "update drupal/core --with-dependencies"
.PHONY: composer
composer:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") composer --working-dir=$(COMPOSER_ROOT) $(filter-out $@,$(MAKECMDGOALS))

## drush	:	Executes `drush` command in a specified `DRUPAL_ROOT` directory (default is `/var/www/html/web`).
##		To use "--flag" arguments include them in quotation marks.
##		For example: make drush "watchdog:show --type=cron"
.PHONY: drush
drush:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush --uri=$(PROJECT_NAME).$(DOMAIN) -r $(DRUPAL_ROOT) $(filter-out $@,$(MAKECMDGOALS))

.PHONY: tmp
tmp:
	echo ${DRUPAL_ROOT}

.PHONY: clean_database_test
clean_database_test:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}")  mysql -u root -padmin -e "DROP DATABASE test;CREATE DATABASE test;" $(filter-out $@,$(MAKECMDGOALS))

.PHONY: phpunit
phpunit:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  sudo -u www-data /var/www/html/vendor/phpunit/phpunit/phpunit -v -c /var/www/html/phpunit.xml $(EXTRA)

.PHONY: clone_repo
clone_repo:
	rm -rf html
	git clone -b ${REPO_DRUPAL_TAG} ${REPO_DRUPAL} html
	docker-compose down && docker-compose up -d

.PHONY: install_drupal
install_drupal:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}")  mysql -u root -padmin -e "DROP DATABASE drupal;CREATE DATABASE drupal;"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush -r /var/www/html/web site-install ${PROFILE} --db-url=mysql://root:admin@${PROJECT_NAME}_mysql:3306/drupal --account-pass=admin --uri=http://$(PROJECT_NAME).$(DOMAIN) -y

.PHONY: uninstall_drupal
uninstall_drupal:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}")  mysql -u root -padmin -e "DROP DATABASE drupal; CREATE DATABASE drupal;"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  rm -f /var/www/html/web/sites/default/settings.php
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  rm -rf /var/www/html/web/sites/default/files
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  mkdir files
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  sudo chown -R www-data:www-data /var/www/html

.PHONY: add_required_files_install
add_required_files_install:
	cp drupal_files_default/default.settings.php $(DRUPAL_ROOT)/sites/default/default.settings.php
	cp drupal_files_default/default.services.yml $(DRUPAL_ROOT)/sites/default/default.services.yml

.PHONY: set_permissions
set_permissions:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  sudo chown -R www-data:www-data /var/www/html

.PHONY: download_drupal_civicrm
download_drupal_civicrm:
	rm -rf html
	mkdir html
	git clone -b ${REPO_DRUPAL_CIVICRM_TAG} ${REPO_DRUPAL_CIVICRM} html
	docker-compose down && docker-compose up -d
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") composer install --working-dir=$(COMPOSER_ROOT)

## logs	:	View containers logs.
##		You can optinally pass an argument with the service name to limit logs
##		logs php	: View `php` container logs.
##		logs nginx php	: View `nginx` and `php` containers logs.
.PHONY: logs
logs:
	@docker-compose logs -f $(filter-out $@,$(MAKECMDGOALS))

# https://stackoverflow.com/a/6273809/1826109
%:
	@: