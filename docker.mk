include .env

default: up

COMPOSER_ROOT ?= /var/www/html
DRUPAL_ROOT ?= /var/www/html/web
SUFFIX_CONTAINER ?= _civicrm
NAME_CONTAINER=$(PROJECT_NAME)$(SUFFIX_CONTAINER)


SUFFIX_CONTAINER_MYSQL ?= _mysql
NAME_CONTAINER_MYSQL=$(PROJECT_NAME)$(SUFFIX_CONTAINER_MYSQL)

IP_CONTAINER=$(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(NAME_CONTAINER))
IP_CONTAINER_MYSQL=$(shell docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(NAME_CONTAINER_MYSQL))

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

.PHONY: drush_uli
drush_uli:
	@echo "Opening browser with one-time login link..."
	xdg-open $(shell docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush --uri=$(PROJECT_NAME).$(DOMAIN) -r $(DRUPAL_ROOT) uli)

.PHONY: cv
cv:
	docker exec -w $(DRUPAL_ROOT) $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") cv $(filter-out $@,$(MAKECMDGOALS))

.PHONY: clean_database_test
clean_database_test:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin -e "DROP DATABASE IF EXISTS test; CREATE DATABASE test;" $(filter-out $@,$(MAKECMDGOALS))

.PHONY: phpunit_setup
phpunit_setup:
	rm -rf html/phpunit.xml
	cp phpunit.xml.dist html/phpunit.xml
	sed -ri 's/name\=\"SIMPLETEST_DB\"\ value\=\"(.*)\"/name\=\"SIMPLETEST_DB\"\ value\=\"mysql:\/\/root\:admin\@$(PROJECT_NAME)_mysql\:3306\/test\"/g' html/phpunit.xml
	sed -ri 's/name\=\"SIMPLETEST_BASE_URL\"\ value\=\"(.*)\"/name\=\"SIMPLETEST_BASE_URL\"\ value\=\"http\:\/\/$(IP_CONTAINER)\"/g' html/phpunit.xml
	sed -ri 's/name\=\"BROWSERTEST_OUTPUT_BASE_URL\"\ value\=\"(.*)\"/name\=\"BROWSERTEST_OUTPUT_BASE_URL\"\ value\=\"http\:\/\/$(PROJECT_NAME)\.localhost\"/g' html/phpunit.xml
	sed -i 's/ALIAS_SELENIUM/$(PROJECT_NAME)_selenium/g' html/phpunit.xml
	mkdir -p html/web/sites/simpletest/browsertests

.PHONY: phpunit
phpunit:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") sudo -u www-data /var/www/html/vendor/phpunit/phpunit/phpunit -v -c /var/www/html/phpunit.xml $(EXTRA)

.PHONY: clone_repo
clone_repo:
	rm -rf html
	git clone -b ${REPO_DRUPAL_TAG} ${REPO_DRUPAL} html

.PHONY: download_repo
download_repo:
	rm -rf html
	mkdir html
	wget -O html/drupal.zip ${REPO_DRUPAL_ZIP}
	unzip -d html html/drupal.zip
	rm html/drupal.zip
	docker-compose down && docker-compose up -d

.PHONY: install_drupal
install_drupal:
	# Related issue with multisite
	# Check if exist directory settings
	if [ docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") -d $(DRUPAL_ROOT)/sites/default ]; then \
		docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") mkdir $(DRUPAL_ROOT)/sites/default; \
	fi
	# Check if exist file settings.php
	if [ docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") -f $(DRUPAL_ROOT)/sites/default/settings.php ]; then \
		docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") cd $(DRUPAL_ROOT)/sites/default/ && wget https://raw.githubusercontent.com/drupal/drupal/$(REPO_DRUPAL_TAG)/sites/default/default.settings.php; \
	fi
	# Overwrite all set_permissions
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") sudo chmod 777 $(DRUPAL_ROOT)/sites/default
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin -e "DROP DATABASE IF EXISTS drupal; CREATE DATABASE drupal;"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush -r $(DRUPAL_ROOT) site-install ${PROFILE} --db-url=mysql://root:admin@${PROJECT_NAME}_mysql:3306/drupal --account-pass=admin --uri=http://$(PROJECT_NAME).$(DOMAIN) -y
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") sudo chmod 777 $(DRUPAL_ROOT)/sites/default
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") drush -l http://${PROJECT_NAME}.${DOMAIN} -r $(DRUPAL_ROOT) en $(MODULES) -y
	make set_permissions

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
	sudo rm -rf html
	mkdir html
	git clone -b ${REPO_DRUPAL_CIVICRM_TAG} ${REPO_DRUPAL_CIVICRM} html
	docker-compose down && docker-compose up -d
#	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") composer install --working-dir=$(COMPOSER_ROOT)

# ToDO get the credenctials with `drush @alias sql-connect`
.PHONE: sync_external_db
sync_external_db:
#Pending to set a bigger insert in the external SET GLOBAL bulk_insert_buffer_size = 1024 * 1024 * 256;
	ssh $(SSH_REMOTE_EXTRA_PARAMS) $(SSH_REMOTE_USER)@$(SSH_REMOTE_HOST) "mysqldump --skip-triggers -u $(MYSQL_REMOTE_USER) -p$(MYSQL_REMOTE_PASS) -h $(MYSQL_REMOTE_HOST) $(MYSQL_REMOTE_DB)" | gzip > $(MYSQL_REMOTE_DB).sql.gz
	gunzip  $(MYSQL_REMOTE_DB).sql.gz
	docker cp $(MYSQL_REMOTE_DB).sql $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}"):/$(MYSQL_REMOTE_DB).sql
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin -e "DROP DATABASE IF EXISTS drupal; CREATE DATABASE drupal;"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") ls /
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") echo $(MYSQL_REMOTE_DB).sql
	docker exec -i $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") mysql -u root -padmin drupal < $(MYSQL_REMOTE_DB).sql $(filter-out $@,$(MAKECMDGOALS))
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_mysql' --format "{{ .ID }}") rm $(MYSQL_REMOTE_DB).sql
	sudo rsync -uzva --no-l -e "ssh $(SSH_REMOTE_EXTRA_PARAMS)" $(SSH_REMOTE_USER)@$(SSH_REMOTE_HOST):$(SSH_REMOTE_PATH)/files/civicrm html/web/sites/default/files/
	sudo rsync -uzva --no-l -e "ssh $(SSH_REMOTE_EXTRA_PARAMS)" $(SSH_REMOTE_USER)@$(SSH_REMOTE_HOST):$(SSH_REMOTE_PATH)/modules html/web/sites/default
	sudo rsync -uzva --no-l -e "ssh $(SSH_REMOTE_EXTRA_PARAMS)" $(SSH_REMOTE_USER)@$(SSH_REMOTE_HOST):$(SSH_REMOTE_PATH)/themes html/web/sites/default
	sudo rsync -uzva --no-l -e "ssh $(SSH_REMOTE_EXTRA_PARAMS)" $(SSH_REMOTE_USER)@$(SSH_REMOTE_HOST):$(SSH_REMOTE_PATH)/libraries html/web/sites/default
	sudo rsync -uzva --no-l -e "ssh $(SSH_REMOTE_EXTRA_PARAMS)" $(SSH_REMOTE_USER)@$(SSH_REMOTE_HOST):$(SSH_REMOTE_PATH)/vendor html/web/sites/default
	make set_permissions

.PHONY connect_vpn:
connect_vpn:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") vpnc-connect --local-port 0 $(VPN_CONFIG_FILE)
# ToDo veifry if exist previously the register in /etc/hosts
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}")  /bin/sh -c "echo $(IP_CONTAINER_MYSQL) $(NAME_CONTAINER_MYSQL) >> /etc/hosts"
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") cat /etc/hosts

.PHONY disconnect_vpn:
disconnect_vpn:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") vpnc-disconnect

.PHONY: logs
logs:
	@docker-compose logs -f $(filter-out $@,$(MAKECMDGOALS))

.PHONY: get_ipv_vpn
get_ipv_vpn:
	docker exec $(shell docker ps --filter name='^/$(PROJECT_NAME)_civicrm' --format "{{ .ID }}") ip addr show tun0 | grep -Po 'inet \K[\d.]+'

# https://stackoverflow.com/a/6273809/1826109
%:
	@: