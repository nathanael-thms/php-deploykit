# php-deploykit

php-deploykit is a project, currently in development that allows deployment of php apps in two ways: [classical](#classical-deployment) and [symblink](#symblink-deployment) (recommended), on linux servers

## Table of contents

- [Installation](#installation)
- [.env variables](#env-variables)
- [Classical deployment](#classical-deployment)
- [Symblink deployment](#symblink-deployment)

## Installation

1. Install the required packages listed in [required packages](#required-packages)
2. Get the code, this can be done via git clone on https(recommended), via github CLI, or you can download a .zip. the repo url is https://github.com/nathanael-thms/php-deploykit.git, so if you use git clone, you would run:
```bash
git clone https://github.com/nathanael-thms/php-deploykit.git
```
3. Make sure run.sh is executable, this is the only file that must be, as scripts called from it are run with the bash command, you can do this by running the following from in the directory you cloned it
```bash
chmod +x php-deploykit/run.sh
```
4. If you would like to do a global install(be able to call it from any directory), execute the below in the directory you cloned it/installed it, assuming the folder is called php-deploykit. Don't run inside the installed directory itself, but it's parent, where php-deploykit is a child of it.
```bash
# If you have more than one app, you may want to move it to something else, eg.
# sudo cp -r php-deploykit /opt/php-deploykit-app
# sudo ln -s /opt/php-deploykit-app/run.sh /usr/local/bin/php-deploykit-app

# move code
sudo cp -r php-deploykit /opt/php-deploykit

# create symlink of run.sh into PATH
sudo ln -s /opt/php-deploykit/run.sh /usr/local/bin/php-deploykit
```
In future steps, where it is said run php-deploykit, run the run.sh script , wherever it sits. If you used the above to symblink it into PATH, you can simply run php-deploykit, or if you changed the name, run that. eg. php-deploykit-app. If you did not symblink it, run {php-deploykit directory/run.sh}

5. Create a .env file derived from .env.example, simply run the command below from inside the deploykit directory, then fill in/change the .env variables described in [.env syntax](#env-variables)
```bash
cp .env.example .env
```
6. Run the initial deployment, run php-deploykit and select option 3(or with the first flag), it should succeed

## Required packages

php-deploykit aims to use as little packages as possible that are not part of coreutils(the packages preinstalled in virtually all linux distributions, such as cp, mv and ls), however, some still need to be installed

- PHP, you almost certainly have this, since you are hosting a php application
- Composer
- Nodejs/NPM(if RUN_NPM="true" in .env)
- rsync(required for automatic migration to symblink deployment) (Installed on most linux distributions)
- git(currently the only way to use symblink deployment, though in classical you can turn off git pull in .env, but then you have no there way to retrieve the code)
- SSH(if you are using it as the git clone method) (Installed on most linux distributions)

All the scripts in this app use /bin/bash, although this is present in virtually all linux distributions, you want to ensure it is present


## .env variables

This section will explain the different .env variables and what they do

Think of the .env more like a config file, it does not hold any confidential data

**APP_DIR**: This variable tells the php-deploykit where your app sits.
> [!NOTE]
> If you are using symblink deployment, this is not including current. eg. **DO**: /var/www/app **DON'T**: /var/www/app/current

**SYMBLINK_DEPLOYMENT**: This variable can be set to true or false, it tells the app weather to use symblink deployment. If false, it will use classical
> [!NOTE]
> DO not set it to true unless symblink deployment it actually set up, this means the current and releases are set up, and almost certainly you'll want shared

**GIT_PULL**: Also a true/false only variable, it is only relevant for classical deployment, and will be ignored in symblink deployments. It will almost always be set to true, as there are currently no other automated methods to retrieve the code

**GIT_BRANCH**: This variable is relevant weather you are using classical or symblink. In classical, it specifies which branch to pull from, in symblink, it specifies which branch to clone

**FRAMEWORK**: This specifies which php framework the app , currently, only laravel is supported, though support for symfony is planned soon, and other frameworks may receive support later.

**MIGRATE**: This is a true/false only variable, it is relevant weather using classical or symblink. It tells the deployment script weather to run the migration command. eg. **php artisan migrate**

**OPTIMIZE**: Also a true/false only variable, relevant weather using classical or symblink. Tells the deployment script weather to run the optimization command. eg. **php artisan optimize**

**RUN_NPM**: Also a true/false only variable, relevant weather using classical or symblink. Tells the deployment script weather to run an npm command, specified in the next variable

**NPM_COMMAND**: This specifies the npm command that should be run, this variable can be omitted if RUN_NPM="false", though even if it is present, it will be ignored if RUN_NPM="false". eg. putting build will run **npm run build** in the deployment script

**DOWN_APP**: This is a true/false only variable, it is relevant only when using classical. It tells the deployment script weather to run the necessary command to put the app down before the main deployment process starts, and back up when it finishes successfully. eg. **php artisan down** && **php artisan up**. This is irrelevant for symblink because it is zero-downtime anyway
>[!IMPORTANT]
> If any part of the script fails, it will stay down, you must manually put it back up unless **BRING_APP_UP_ON_FAILURE="true"**

**BRING_APP_UP_ON_FAILURE**: This is a true/false only variable, it is relevant only when using classical and **DOWN_APP="true"** It tells the deployment script weather to run the necessary command to put the app back up if the main deployment process fails at any point, and and it was put down. eg. **php artisan up**. This is irrelevant for symblink because the app will never have been put down
>[!CAUTION]
> This is strongly discouraged, as if it fails during a certain phase, it could leave a half broken app up to the public. This could pose significant vulnerabilities. This is another reason why symblink is great, an unsuccessfully deployed application will never be made public.

**SYMBLINK_DEPLOYMENT_GIT_PATH**: This variable, only relevant for symblink deployment
tells the script where to get the repo, it is recommended to use shh if using github, like this: **SYMBLINK_DEPLOYMENT_GIT_PATH="git@github.com:user/app.git"** This will cause the script to run: git clone --branch "whatever GIT_BRANCH is set to" --depth 1 git@github.com:user/app.git "app_dir/releases/timestamp"

The values must be surrounded with "" quotes to ensure the scripts parse them correctly

Variables that are irrelevant but still inputted will simply be ignored

## Usage
The php-deploykit command/run.sh file can be run with options, here they are listed.

| Flag | Function |
|---|---|
| deploy | The same as running without flags and selecting option 1, does a classical/symblink deployment, following the settings in .env. Does not require human interaction |
| migrate | The same as running without flags and selecting option 2, starts migration to symlink deployment as described in [migration to symblink deployment](#migration-to-symblink-deployment). Requires human interaction |
| first | The same as running without flags and selecting option 3, starts initial deployment, this only makes a difference in classical, doing this in symblink will just do the same as option 1. ONLY USE FOR FIRST DEPLOYMENT. Does not require human interaction, though it is recommended you oversee it, since it is the first deployment |

Only one option at a time may be specified

eg. php-deploykit --deploy

Running it without specifying an option will give you a menu, and you may select 1, 2 or 3, more detailed info can be found below:

### Option 1/deploy

This calls the deploy-logic/deploy.sh script, this script checks .env, sees weather to run symblink or classical, and runs the specific one for your framework, currently, only laravel is supported. So, if in .env, framework is set to laravel and symblink deployment is true, it runs deploy-logic/laravel/deploy_symblink.sh

### Option 2/migrate

This is for migration to symlink deployment as described in [migration to symblink deployment](#migration-to-symblink-deployment). It calls utilities/migrate_to_symblink.sh

### Option 3/first

Does the exact same as option 1, just ensures, if using classical deployment, that the app down command. eg. php artisan down is not run.

## Classical deployment

Classical is a normal deployment, it puts the app down(if DOWN_APP="true") in .env, runs the relevant commands, and if the app was put down, it puts it back up

## Symblink deployment

Symblink deployment(recommended) is a more modern, zero-downtime and reversible deployment, every time run, it clones the git repo(truncated to 1 commit) into {app directory}/releases/{timestamp}, runs deployment there, then, after all is completed, creates/overwrites the existing symblink to the {app directory}/current/ directory, this is where you point your web server. Symblink deployment also allows for a {app directory}/shared/ directory, and in every deployment, all files/directories in shared are symblinked to the new release directory(which becomes symblinked to the current directory after completion of deployment), this is useful for things like the 'storage folder' and .env files

> [!WARNING]
> If a file/directory in the shared folder already exists in the new releases folder, it will be overwritten by the symblink, this is by design, for example, laravel does include the storage directory in git, just all it's contents are gitignored, then the empty storage folder will be overwritten by the symblink, making it persistent across deployments

### Migration to symblink deployment

This is always a headache, so this web app includes a script to do this automatically, it does everything except clear caches/recache and change your web servers config, to run the script, run php-deploykit, choose option 2, and follow the prompts, afterwards, clear/recache as instructed, and change your web server to point to the new 'current' directory

> [!CAUTION]
> Read the prompts of the script carefully, failure to do this could pose a security risk

To symblink files, move them to app dir/shared, and redeploy