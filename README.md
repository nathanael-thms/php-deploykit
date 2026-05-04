# php-deploykit

php-deploykit is a project that allows deployment of PHP apps in two ways: classical and symlink (recommended) on Linux servers.

## Documentation

Documentation is available at [https://deploykit.nattho.com](https://deploykit.nattho.com).

## Features

- Zero downtime deployments (symlink method)
- Easy rollbacks (symlink method)
- Auto migration to symlink
- Automatic webhook support for GitHub, GitLab, and Bitbucket
- View if the deployment passed, failed or is in progress just by checking on the GitHub commit page(if using GitHub and enabled)
- Logging system
- Easy log viewing, see at a glance which deployments failed and which succeeded(color coded), and view the logs for each deployment without manually opening the log files
- Automatic cleanup of old releases, keeping the latest releases specified with `KEEP_RELEASES` in .env(if enabled)
- Easy configuration with .env file
- Robust pre-flight checks
- Run your own custom commands at 3 points in deployment
- Open source and free to use

## Supported frameworks

php-deploykit currently supports Laravel and Symfony, but support for other frameworks may be added in the future. If you want to contribute support for your favorite framework, feel free to open a pull request.