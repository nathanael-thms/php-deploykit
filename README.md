# php-deploykit

php-deploykit is a project currently in development that allows deployment of PHP apps in two ways: [classical](#classical-deployment) and [symlink](#symlink-deployment) (recommended) on Linux servers.

> [!WARNING]
> Use in production environments at your own risk, but it is **not yet recommended**. Breaking changes may occur before the v1.0.0 release.

## Table of contents

- [Installation](#installation)
- [.env variables](#env-variables)
- [Usage](#usage)
- [Logging](#logging)
- [Webhook listener](#webhook-listener)
- [Classical deployment](#classical-deployment)
- [Symlink deployment](#symlink-deployment)
- [License](#license)

## Installation

1. Install the required packages listed in [Required packages](#required-packages).
2. Get the code. This can be done via `git clone` over HTTPS (recommended), via the GitHub CLI, or by downloading a .zip. The repository URL is https://github.com/nathanael-thms/php-deploykit.git; to clone, run this command to download the latest version:
```bash
git clone --branch v0.2.0 --depth 1 https://github.com/nathanael-thms/php-deploykit.git
```
3. Make sure `run.sh` is executable. This is the only file that must be executable because scripts called from it are run with `bash`. From the directory you cloned the repository, run:
```bash
chmod +x php-deploykit/run.sh
```
4. If you would like to install globally (callable from any directory), run the following from the parent directory of `php-deploykit` (do not run this inside the `php-deploykit` directory). Replace the target path or name as desired.
```bash
# If you have more than one app, you may want to move it to something else, eg.
# sudo cp -r php-deploykit /opt/php-deploykit-app
# sudo ln -s /opt/php-deploykit-app/run.sh /usr/local/bin/php-deploykit-app

# move code
sudo cp -r php-deploykit /opt/php-deploykit

# create symlink of run.sh into PATH
sudo ln -s /opt/php-deploykit/run.sh /usr/local/bin/php-deploykit
```
In later steps, when instructed to "run php-deploykit", execute the `run.sh` script from its installation location. If you created a symlink into `PATH`, you can run `php-deploykit` (or the name you chose). Otherwise run the script using the full path to the `run.sh` file.

5. Create a .env file derived from .env.example, simply run the command below from inside the deploykit directory, then fill in/change the .env variables described in [.env syntax](#env-variables)
```bash
cp .env.example .env
```
6. Run the initial deployment: execute `php-deploykit` and select option 4 (or use the corresponding flag). It should succeed.

## Required packages

php-deploykit aims to use as few packages as possible beyond the coreutils included in most Linux distributions (for example `cp`, `mv`, and `ls`), but some packages are required or recommended:

- PHP (required to host a PHP application)
- Composer
- Node.js / npm (if `RUN_NPM="true"` in `.env`)
- rsync (required for automatic migration to symlink deployment; installed on most Linux distributions)
- git (required for symlink deployment; in classical mode you can disable `git pull`, but then there is no automated way to retrieve code)
- SSH (if you use it for git cloning; installed on most Linux distributions)
- python3 (required for the webhook listener; installed on most Linux distributions)

All scripts use `/bin/bash`; although present on most Linux distributions, ensure it is installed.


## .env variables

This section explains the `.env` variables and what they do.

Think of the `.env` as a configuration file; it does not hold confidential data.

**APP_DIR**: This variable tells php-deploykit where your app is located.
> [!NOTE]
> If you are using symlink deployment, this should not include `current`. For example, use `/var/www/app` rather than `/var/www/app/current`.

**SYMLINK_DEPLOYMENT**: Set to `true` or `false`. When `true`, the script uses symlink deployment; when `false`, it uses classical deployment.
> [!NOTE]
> Do not set this to `true` unless symlink deployment is actually set up (that is, `current` and `releases` directories exist). You will most likely also want a `shared` directory.

**GIT_PULL**: A `true`/`false` variable relevant only for classical deployment; it is ignored for symlink deployments. It will usually be `true`, since there is currently no other automated method to retrieve code.

**GIT_BRANCH**: This variable is relevant whether you are using classical or symlink. In classical, it specifies which branch to pull from, in symlink, it specifies which branch to clone

**FRAMEWORK**: Specifies which PHP framework the app uses. Currently only Laravel is supported; Symfony support is planned.

**MIGRATE**: A `true`/`false` variable relevant for both classical and symlink deployments. When `true`, the deployment script runs the migration command (for example, `php artisan migrate`).

**OPTIMIZE**: A `true`/`false` variable relevant for both deployment types. When `true`, the deployment script runs the optimization command (for example, `php artisan optimize`).

**RUN_NPM**: A `true`/`false` variable relevant for both deployment types. When `true`, the deployment script runs an npm command specified by `NPM_COMMAND`.

**NPM_COMMAND**: Specifies the npm command to run. This can be omitted if `RUN_NPM="false"`; if present but `RUN_NPM="false"`, it will be ignored. For example, setting `build` runs `npm run build`.

**LOG**: A `true`/`false` variable relevant for both deployment types. When `true`, the deployment script stores output in a log file specified by `LOG_FILE`.

**LOG_FILE**: Specifies where to store logs. This can be omitted if `LOG="false"`; if present but `LOG="false"`, it will be ignored. Ensure you have permissions to write to the specified file; if the file does not exist, the script will try to create it and may fail if you lack permissions for the parent directory.

**DOWN_APP**: A `true`/`false` variable relevant only for classical deployment. When `true`, the deployment script runs the command to put the app down before deployment and bring it back up on success (for example, `php artisan down` && `php artisan up`). symlink deployment is zero-downtime, so this is not used there.
> [!IMPORTANT]
> If any part of the script fails while the app is down, it will remain down. You must manually bring it back up unless `BRING_APP_UP_ON_FAILURE="true"`.

**BRING_APP_UP_ON_FAILURE**: A `true`/`false` variable relevant only for classical deployment when `DOWN_APP="true"`. When `true`, the deployment script will attempt to bring the app back up if the main deployment process fails and the app had been put down (for example, `php artisan up`). This is not used for symlink deployments.
> [!CAUTION]
> This is strongly discouraged: if bringing the app back up fails during a partially completed deployment, it could expose a broken application to the public and create security risks. This is one reason symlink deployments are preferable: a failed deployment will not be made public.

**SYMLINK_DEPLOYMENT_GIT_PATH**: Relevant only for symlink deployment; this tells the script where to clone the repository. For GitHub, using SSH is recommended, for example: `SYMLINK_DEPLOYMENT_GIT_PATH="git@github.com:user/app.git"`. The script will run a command similar to:

`git clone --branch "<GIT_BRANCH>" --depth 1 git@github.com:user/app.git "<APP_DIR>/releases/<timestamp>"`

**AUTO_CLEANUP**: A `true`/`false` variable relevant only for symlink deployment. When `true`, the script automatically cleans up old releases, keeping the latest `KEEP_RELEASES` releases.

**KEEP_RELEASES**: This variable, only relevant for symlink deployment and when **AUTO_CLEANUP="true"** tells the auto cleanup script to keep the latest **KEEP_RELEASES** releases

**WEBHOOK_PORT**: This variable is used to specify the port the webhook listener uses to listen on.

**WEBHOOK_SECRET**: This variable is used to specify the secret the webhook listener uses to verify incoming requests.

**WEBHOOK_PROVIDER**: This variable is used to specify the provider the webhook listener is expecting requests from. Supported values are `github`, `gitlab` and `bitbucket`.

**LOG_WEBHOOK**: A `true`/`false` variable that specifies whether to log incoming webhook requests. If `true`, logs are stored in the file specified by `WEBHOOK_LOG_FILE`. Unless you are debugging, there is no need to log webhook requests, so it is recommended to set this to `false` in production.

**WEBHOOK_LOG_FILE**: Specifies where to store logs of incoming webhook requests. This can be omitted if `LOG_WEBHOOK="false"`; if present but `LOG_WEBHOOK="false"`, it will be ignored. Ensure you have permissions to write to the specified file; ensure the file exists.

Values must be surrounded by double quotes (`""`) so the scripts parse them correctly.

Variables that are irrelevant to the chosen deployment mode will be ignored.

## Usage
The `php-deploykit` command / `run.sh` can be run with options. Available flags:

| Flag | Function |
|---|---|
| `deploy` | Same as running without flags and selecting option 1. Performs a classical or symlink deployment according to `.env`. Does not require user interaction. |
| `migrate` | Same as selecting option 2. Starts migration to symlink deployment as described in [Migration to symlink deployment](#migration-to-symlink-deployment). Requires user interaction. |
| `revert` | Same as selecting option 3 (symlink only). Reverts to a previous deployment as described in [Reverting to a previous deployment](#reverting-to-a-previous-deployment). Requires user interaction. |
| `first` | Same as selecting option 4. Use this for the initial deployment; it prevents the app-down command from being run in classical mode. Does not require user interaction but oversight is recommended. |
| `cleanup` | Same as selecting option 5 (symlink only). Cleans up old releases as described in [Cleaning up old releases](#cleaning-up-old-releases). Can be followed by `-<n>` (for example `--cleanup-10`) to keep the latest `n` releases. Requires user interaction if not followed by an integer. |
| `logs` | Same as selecting option 6. Displays all the deployments, red if failed and green if successful. Then prompts for you to select a deployment to view logs for. If all you wanted to do is check if it was successful, press Ctrl+C after viewing the logs. |
| `webhook_listener` | Starts the webhook listener. Meant to be executed by a systemd service. |
| `webhook-service-install` | Installs the webhook listener as a systemd service. |
| `webhook-service-uninstall` | Uninstalls the webhook listener systemd service. |
| `help` | Prints the available flags. |

Only one option may be specified at a time. Example:

`php-deploykit --deploy`

Running without flags presents a menu where you can select 1, 2, 3, 4, 5, 6 or 7. More detailed information on each option follows.

### Option 1/deploy

This calls `deploy-logic/deploy.sh`. That script checks `.env` to determine whether to use symlink or classical deployment, then runs the framework-specific deployment script. Currently only Laravel is supported; for Laravel with symlink enabled it runs `deploy-logic/laravel/deploy_symlink.sh`.

### Option 2/migrate

This starts the migration to symlink deployment as described in [Migration to symlink deployment](#migration-to-symlink-deployment). It calls `utilities/migrate_to_symlink.sh`.

### Option 3/revert

This reverts to a previous deployment when using symlink deployment, as described in [Reverting to a previous deployment](#reverting-to-a-previous-deployment). It calls `utilities/revert_to_previous_deployment.sh`.

### Option 4/first

Performs the same actions as option 1 but ensures that the app-down command (for example `php artisan down`) is not run in classical deployment.

### Option 5/cleanup

Cleans up old releases when using symlink deployment, as described in [Cleaning up old releases](#cleaning-up-old-releases). It calls `utilities/clean_up_releases.sh`.

### Option 6/logs.

Displays all deployments, red if failed and green if successful. Then prompts for you to select a deployment to view logs for. Only works if logging is enabled. If all you wanted to do is check if it was successful, press Ctrl+C after viewing the logs. It calls `utilities/view_logs.sh`.

### webhook_listener

This purposefully must be executed by flags, to prevent accidental running when mistyping the selection. It starts the webhook listener, which listens for incoming webhook requests and triggers deployments when a request is received. It calls `webhook_listener/webhook_listener.sh`. It is recommended to run this via a systemd.

### Option 7/webhook-service-install

This installs the webhook listener as a systemd service. It calls `utilities/webhook_listener_service_install.sh`, which creates a systemd service file for the webhook listener and starts the service. The service is configured to start on boot and restart automatically if it fails.

### webhook-service-uninstall

This uninstalls the webhook listener systemd service. It calls `utilities/webhook_listener_service_uninstall.sh`, which stops the service, disables it from starting on boot, and removes the service file. Can not be run with option number to prevent accidents

## Logging

php-deploykit can log deployment output to a file specified by `LOG_FILE` in `.env`. If `LOG="true"`, the script stores output in the log file; if `LOG="false"`, it does not. Ensure you have permissions to write to the specified file; if the file does not exist, the script will try to create it and may fail if you lack permissions for the parent directory.

Every time you run a command via run.sh, it creates a new log entry with the date and time. You can view logs for a specific deployment by running `php-deploykit --logs` or selecting option 6 from the menu.

### Webhook logging

This is a much less common use case, but php-deploykit can also log incoming webhook requests if `LOG_WEBHOOK="true"` in `.env`. If enabled, logs are stored in the file specified by `WEBHOOK_LOG_FILE`. This is meant for debugging; unless you are debugging, it is recommended to set `LOG_WEBHOOK="false"` in production.

There is no polished interface for viewing webhook logs; you can view them by opening the log file directly.

> [!NOTE]
> You should still view logs to make sure the deploykit runs are executing successfully when using the webhook listener, even if you do not log webhook requests. A good way to do a first test is by checking how many runs are available with `php-deploykit --logs` before sending a test webhook, then sending the test webhook and checking if a new run appears in the logs, it should be in green. If it appears, but read, you can check the error there, if you still cannot figure it out, or no run appears, enable webhook logging and trigger another test webhook, then check the webhook log file for errors.

> [!NOTE]
> You must use systemctl to restart the webhook listener if you change the .env variables related to the webhook listener, since the listener only reads those variables on startup.

## Webhook listener

The webhook listener listens for incoming webhook requests and triggers deployments when a request is received. It uses the `WEBHOOK_PORT`, `WEBHOOK_SECRET`, and `WEBHOOK_PROVIDER` variables in `.env` to determine how to listen for requests and verify them. It is recommended to run the webhook listener via a systemd service.

### Install as a service(recommended)

To install the webhook listener as a systemd service, run php-deploykit --webhook-service-install or select the corresponding option from the menu. This runs the `utilities/webhook_listener_service_install.sh` script, which creates a systemd service file for the webhook listener and starts the service. The service is configured to start on boot and restart automatically if it fails.

To remove, run `php-deploykit --webhook-service-uninstall` or select the corresponding option from the menu. This stops the service, disables it from starting on boot, and removes the service file.

## Classical deployment

Classical deployment is a standard deployment process. If `DOWN_APP="true"`, the script will put the app down, run the relevant commands, and bring the app back up on success.

## Symlink deployment

Symlink deployment (recommended) is a zero-downtime, reversible deployment method. Each run clones the Git repository (shallow, depth 1) into `{app directory}/releases/{timestamp}`, runs the deployment there, and then updates the `current` symlink to point at the new release directory (this is what your web server should point to). symlink deployment also supports a `{app directory}/shared/` directory; files and directories in `shared` are symlinked into the new release, which keeps data like the `storage` folder and `.env` files persistent across deployments.

> [!WARNING]
> If a file or directory in the `shared` folder also exists in the new release, it will be overwritten by the symlink. This is by design. For example, Laravel includes the `storage` directory in Git but ignores its contents; the empty `storage` folder in the repository will be replaced by the symlink to the persistent `storage` in `shared`.

### Migration to symlink deployment

Migration to symlink deployment can be complicated. This project includes a script to automate the process; it performs all steps except clearing/recaching application caches and updating your web server configuration. To run the script, execute `php-deploykit`, choose option 2, and follow the prompts. Afterwards clear and recache the application as instructed and update your web server to point to the new `current` directory.

> [!CAUTION]
> Read the script prompts carefully; failure to follow instructions may pose a security risk.

To symlink files, move them to `APP_DIR/shared` and redeploy.

### Reverting to a previous deployment

A key advantage of symlink deployment is the ability to revert to a previous deployment if a bug is discovered. The script remaps the `current` symlink to an older release directory. It lists releases in newest-to-oldest order and prompts you to select a number. Although named "revert", the script can also be used to move forward again if needed. To run it, execute `php-deploykit`, choose option 3, and follow the prompts.

### Cleaning up old releases

Over time your server may accumulate many releases. To clean them up, `php-deploykit` includes a cleanup script. When run, if there is more than one release, it prompts for how many releases to keep (for example, entering `10` keeps the 10 newest releases and deletes the rest). To run the script, execute `php-deploykit`, choose option 5, and follow the prompts. If you enter a number greater than or equal to the current number of releases, the script does nothing and exits with code 0, which makes automation easier.

> [!CAUTION]
> If you have reverted or manually changed the `current` symlink to an older release, cleaning up by keeping the latest `n` releases may remove the directory pointed to by `current`. This will cause the web server to stop working.

## License

php-deploykit is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file or https://www.apache.org/licenses/LICENSE-2.0 for the full license text.