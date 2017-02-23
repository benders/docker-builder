Using base-alpine-builder:latest
============================

An `ONBUILD`-based Docker image for use with mulitiple languages (Ruby and Python to start). It allows for multiple language runtimes to be installed and is appropriate for web and non-web applications.

The image runs off Alpine Linux (so much smaller than our Centos images) and includes:

  * typical system dependencies and compilation tools
  * nginx -- Since even headless apps need a status check, right?
  * s6 -- Configured to run nginx by default
  * running as `nobody` by default -- Because who doesn't want security?

During your `docker build` the image uses the presence of specific files to trigger particular installation steps:

  * `.preinstall`     -- Runs as shell script for pre-installing native dependencies
  * `.ruby-version`   -- Triggers installation of Ruby via rbenv
  * `.python-version` -- Triggers installation of Python via pyenv
  * `Gemfile`         -- Triggers `bundle install --deployment`
  * `config.ru`       -- Triggers setup for Ruby web application (default Unicorn over Unix socket file, Ruby agent configuration provided)
  * `package.json`    -- Triggers `npm install`

A standard Rails app can run from this image with just a `FROM` line in your `Dockerfile`!

Common alternate usages are also directly supported via scripts in the image (see ["Other Customization"](#other-customization) for a list of options)

* [Examples](#examples)
  * [Native Dependencies](#native-dependencies)
  * [Ruby Configuration](#ruby-configuration)
  * [Python Configuration](#python-configuration)
  * [NPM Configuration](#npm-configuration)
  * [Adding MySQL](#adding-mysql)
  * [Unicorn Web Example](#unicorn-web-example)
  * [Background Example](#background-example)
  * [Puma Instead of Unicorn](#puma-instead-of-unicorn)
  * [Use Port 3000 Instead of Unix Socket](#use-port-3000-instead-of-unix-socket)
* [Running Other Processes](#running-other-processes)
* [Customizing the Environment](#customizing-the-environment)
* [Overriding Files](#overriding-files)
* [Other Common Files](#other-common-files)

## Examples

### Native Dependencies

If you have system prerequisites to install before your language runtimes or libraries, create `.preinstall`

```
apk --no-cache add snappy-dev
```

### Ruby Configuration

In `.ruby-version`:

```
2.3.1
```

To run the Ruby Agent, in your `Gemfile` add:

```
gem 'newrelic_rpm'
```

In your environment (most likely via Centurion config), set the following ENV variables:

```
NEW_RELIC_LICENSE_KEY -- license keys shouldn't be in app git repos

SERVICE_NAME -- site engineering wants this, and by default we'll use it for the app name
or
NEW_RELIC_APP_NAME -- override the agent's app name entirely
```

### Python Configuration

In `.python-version`:

```
3.5.2
```

### NPM Configuration

In `package.json`:

```
{
  "name": "my-app",
  "version": "1.0.0",
  "description": "My App",
  "dependencies": {
    "d3": "^4.2.2",
    "jquery": "^3.1.0",
    "webpack": "^1.13.1"
  },
  "repository": {
    "type": "git",
    "url": "git@source.example.com:my-team/my-app.git"
  }
}
```

### Adding MySQL

In `your_project/.preinstall`:

```
apk add mysql-dev
```

### Unicorn Web Example

In `your_project/Dockerfile`:

```
FROM base-alpine-builder

# For Rails apps, you will want to build assets during container build
RUN ./bin/rake tmp:create assets:precompile
```

*Note:* Make sure that your rails app does not have a unicorn configuration file in your local config directory. This will overwrite the unicorn config in the onbuild image and will prevent your container from serving your application.

### Background Example

In `your_project/Dockerfile`:

```
FROM base-alpine-builder

# Tells the image to run `bin/run` instead of a typical web
RUN use-bin-run
```

In `bin/run` start up your background application.

```
sidekiq -c 20
```

**Note do not daemonize this process!** s6 is responsible for that sort of process management.

### Puma Instead of Unicorn

In `your_project/Dockerfile`:

```
FROM base-alpine-builder

RUN use-puma
```

### Use Port 3000 Instead of Unix Socket

In `your_project/Dockerfile`:

```
FROM base-alpine-builder

# Useful if you're running a separate process (for example via bin/run) that
# uses an internal HTTP server to provide status check.
RUN use-port-3000
```

### Running Other Processes

To run more than one process in your container, create additional /etc/services.d/THING/run files in your project (typically located in the same path as you'll copy them to in the image):

**Note that s6 expects these processes to run in the foreground.** Don't set any explicit daemonizing or forking!

In `etc/services.d/my-custom-process/run`

```

#!/usr/bin/with-contenv sh

exec s6-setuidgid nobody my-custom-process
```

In `your_project/Dockerfile`

```
RUN mkdir -p /etc/services.d/my-custom-process && \
    cp /data/app/etc/services.d/my-custom-process/run /etc/services.d/my-custom-process/run
```

## SECURITY!!!!

**Note that the container runs your processes as `nobody`.** `s6` runs as `root` still, but your processes should be fine with less privileges, right?!

Running as `nobody` means your application code can only write to `/data/app/log` and `/data/app/tmp`. **You should try to only write to those directories!** If you're using a library or code that needs a writable location, see whether it can be configured to work under `/data/app/tmp`. If for some reason it can't, then you'll need to ensure those locations are writable by `nobody`.

## Customizing the Ruby Web Environment

The following Environment Variables can be set:

* `RACK_ENV`, default production
* `UNICORN_WORKERS` to control the number of Unicorn workers, default 2
* `UNICORN_TIMEOUT` amount of second to wait before kill -9'ing a stuck worker, default 90

**Note that the container will run by default with `RACK_ENV=production`.** For Staging, Testing or Development use you will need to override that. This can be done on the docker command line, in Centurion or with Docker Compose.

## Overriding Files

If you want to alter the processes that s6 starts up, you'll need to write commands in your `Dockerfile` that copy things to the right locations in `/etc/services.d/` in the container. See [Running Other Processes](#Running-Other-Processes) for examples.

To override Unicorn's startup configuration, create `config/unicorn_config.rb` in your source.

To override Puma's startup configuration, create `config/puma_config.rb` in your source.

To override New Relic Ruby agent configuration, create `config/newrelic.yml` in your source.

## Other Common Files

```
# your_project/.dockerignore
.dockerignore
.git
.bundle
log
tmp
public/assets
```

```
# your_project/docker-compose.yml
web:
  build: .
  ports:
    - "80:80"
  environment:
    RACK_ENV: development
```
