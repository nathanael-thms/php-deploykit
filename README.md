# php-deploykit

php-deploykit is a project, currently in development that allows deployment of php apps in two ways: classical and symblink.

Classical is a normal deployment, it puts the app down(if DOWN_APP="true") in .env, runs specified commands, and if the app was put down, it puts it back up

Symblink deployment(recommended) is a more modern, zero-downtime and reversible deployment, every time run, it clones the git repo(truncated to 1 commit) into {app directory}/releases/{timestamp}, runs deployment there, then, after all is completed, creates/overwrites the existing symblink to the {app directory}/current/ directory, this is where you point your web server. Symblink deployment also allows for a {app directory}/shared/ directory, and in every deployment, all files/directories in shared are symblinked to the new release directory(which becomes symblinked to the current directory after completion of deployment), this is useful for things like the 'storage folder' and .env files

> [!WARNING]
> If a file/directory in the shared folder already exists in the new releases folder, it will be overwritten by the symblink, this is by design, for example, laravel does include the storage directory in git, just all it's contents are gitignored, then the empty storage folder will be overwritten by the symblink, making it persistent across deployments

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

**GIT_BRANCH**: Also a true/false only variable, however it is relevant weather you are using classical or symblink. In classical, it specifies which branch to pull from, in symblink, it specifies which branch to clone

**FRAMEWORK**: This specifies which php framework the app , currently, only laravel is supported, though support for symfony is planned soon, and other frameworks may receive support later.

**MIGRATE**: This is a true/false only variable, it is relevant weather using classical or symblink. It tells the deployment script weather to run the migration command. eg. **php artisan migrate**

**OPTIMIZE**: Also a true/false only variable, relevant weather using classical or symblink. Tells the deployment script weather to run the optimization command. eg. **php artisan optimize**

**RUN_NPM**: Also a true/false only variable, relevant weather using classical or symblink. Tells the deployment script weather to run an npm command, specified in the next variable

**NPM_COMMAND**: This specifies the npm command that should be run, this variable can be omitted if RUN_NPM="false", though even if it is present, it will be ignored if RUN_NPM="false". eg. putting build will run **npm run build** in the deployment script

**DOWN_APP**: This is a true/false only variable, it is relevant only when using classical. It tells the deployment script weather to run the necessary command to put the app down before the main deployment process starts, and back up when it finishes successfully. eg. **php artisan down** && **php artisan up**. This is irrelevant for symblink because it is zero-downtime anyway
>[!IMPORTANT]
> If any part of the script fails, it will stay down, you must manually put it back up

**SYMBLINK_DEPLOYMENT_GIT_PATH**: This variable, only relevant for symblink deployment
tells the script where to get the repo, it is recommended to use shh if using github, like this: **SYMBLINK_DEPLOYMENT_GIT_PATH="git@github.com:user/app.git"** This will cause the script to run: git clone --branch "whatever GIT_BRANCH is set to" --depth 1 git@github.com:user/app.git "app_dir/releases/timestamp"
