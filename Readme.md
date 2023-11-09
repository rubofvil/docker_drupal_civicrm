# Readme

## Requirements

- Configure a traefik/create lan
  - [traefik](https://github.com/rubofvil/docker_compose_traefik)
- Create a .env file
  - `cp .env.example .env`

## Repos used as reference

- [civicrm-buildkit-docker](https://github.com/michaelmcandrew/civicrm-buildkit-docker)
- [wodby/docker4drupal](https://github.com/wodby/docker4drupal)
- [https://github.com/omega8cc/boa](https://raw.githubusercontent.com/omega8cc/boa/fe07ca47d8a712615b00d2afda79e9952e80408e/aegir/conf/my.cnf.txt)
  - my.cnf

## Steps to migrate

- Add in the .env the var `PROJECT_NAME`
  - The url for the **web** will be `PROJECT_NAME`.localhost
  - The url for the **phpmyadmin** will be `PROJECT_NAME`.phpmyadmin.localhost
  - The url for the mails **phpmyadmin** will be `PROJECT_NAME`.maildev.localhost
- Import the database with user root/admin and the autohost generated
- Move the files to the directory `html`.
  - Modify `civicrm.settings.php` and `settings.php`

Example to use with vscode with xdebug with xdebug

```json
{
  "launch": {
    "version": "0.2.0",
    "configurations": [
      {
        "name": "Listen for XDebug",
        "type": "php",
        "request": "launch",
        "port": 9003,
        "pathMappings": {
          "/var/www/html": "{TO_REPLACE_WITH_LOCAL_PATH}/docker_drupal_civicrm/html",
        },
        "xdebugSettings": {
          "max_children": 200
        },
        "log": true,
      },
      {
        "name": "Launch currently open script",
        "type": "php",
        "request": "launch",
        "program": "${file}",
        "cwd": "${fileDirname}",
        "port": 9000
      }
    ]
  }
}
```

## Rules to add ufw for xdebug

```bash
sudo ufw allow from 172.18.0.0/24 to any port 9003
sudo ufw allow from 172.17.0.1 to any port 9003
```

## Example of use PHPUNIT

- `make phpunit`

`EXTRA="--filter testAssignContributionSecondContactSelectByUser /var/www/html/web/modules/contrib/webform_civicrm/tests/src/FunctionalJavascript/ContributionDummyTest.php" make phpunit`

Example to execute phpunit in

```bash
sudo -u www-data vendor/phpunit/phpunit/phpunit -v -c ./phpunit.xml web/modules/contrib/webform_civicrm/tests/src/FunctionalJavascript/ActivitySubmissionTest.php
```
