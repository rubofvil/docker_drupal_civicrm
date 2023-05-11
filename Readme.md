# Readme

## Steps to migrate

- Add in the .env the var `PROJECT_NAME`
  - The url for the **web** will be `PROJECT_NAME`.localhost
  - The url for the **phpmyadmin** will be `PROJECT_NAME`.localhost
  - The url for the mails **phpmyadmin** will be `PROJECT_NAME`.maildev.localhost
- Import the database with user root/admin and the autohost generated
- Move the files to the directory `html`.
  - Modify `civicrm.settings.php` and `settings.php`
Example to use with vscode with xdebug

```json
{
  // Use IntelliSense to learn about possible attributes.
  // Hover to view descriptions of existing attributes.
  // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for XDebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "pathMappings": {
        // setup local folder mapping as example
        "/var/www/html/web": "{$LOCAL_PATH}/html/web"
      },
      "xdebugSettings": {
        "max_children": 200
        //"max_data": 1024,
        //"max_depth": 4,
        //"show_hidden": 1
      },
      "log": true,
      // optional to stop at the beginning of execution
      "stopOnEntry": true
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
```

## Rules to add ufw

´´´bash
sudo ufw allow from 172.18.0.0/24 to any port 9003
sudo ufw allow from 172.17.0.1 to any port 9003
´´´

## Example of use MAKE

- `make phpunit`

`EXTRA="--filter testAssignContributionSecondContactSelectByUser /var/www/html/web/modules/contrib/webform_civicrm/tests/src/FunctionalJavascript/ContributionDummyTest.php" make phpunit`
