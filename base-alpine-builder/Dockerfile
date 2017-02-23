FROM alpine:3.4

RUN apk --no-cache update && \
    apk add --no-cache ca-certificates

# Set up working directory
WORKDIR /data/app
RUN mkdir -p tmp config log

ENV BUILD_PKGS="curl build-base ruby-dev linux-headers readline-dev zlib-dev openssl-dev" \
    SUPPORT_PKGS="bash openssh-client nginx"

# Update and install all of the required packages.
# without saving the cache
RUN echo 'gem: --no-ri --no-rdoc --no-document' > /etc/gemrc && \
    apk --no-cache upgrade && \
    apk --no-cache add $BUILD_PKGS $SUPPORT_PKGS

ENV S6_OVERLAY_VERSION=v1.18.1.5

RUN apk add --no-cache tar curl ca-certificates && \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz \
    | tar xzf - -C /

# Nginx setup... doesn't seem to like running without this and won't create it
RUN mkdir -p /run/nginx

# Copy our support files in
COPY bin/* /usr/bin/
COPY etc /etc

# For back-compat with base-builder, copy over bin files to etc too
# Preferred usage is without /etc/* though
COPY bin/* /etc/

# To get ENV to stick, include all possibilities whether installed or not
ENV RACK_ENV production
ENV RBENV_ROOT /usr/local/rbenv
ENV PATH /usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH

ENV PYENV_ROOT /usr/local/pyenv
ENV PATH /usr/local/pyenv/shims:/usr/local/pyenv/bin:$PATH

# Everybody runs a status check at least, right?
EXPOSE 80

ENTRYPOINT ["/init"]
CMD []

# Why Dockerfile*? COPY fails on an empty list, so we've got to
# match *something* to effectively optionally COPY files in.
# /etc/try-* scripts do the conditional work after the COPY.

# Language runtimes
ONBUILD COPY Dockerfile* compose* .ruby* /data/app/
ONBUILD RUN try-ruby

ONBUILD COPY Dockerfile* compose* .python* /data/app/
ONBUILD RUN try-python

# Native dependencies for gem/app
ONBUILD COPY Dockerfile* compose* .preinstall* /data/app/
ONBUILD RUN try-preinstall

# NPM modules
ONBUILD COPY Dockerfile* compose* package.json* /data/app/
ONBUILD RUN try-npm

# Set up for Ruby web apps to run
ONBUILD COPY Dockerfile* compose* config.ru* /data/app/
ONBUILD RUN try-ruby-webapp

# Application-level tweaking
ONBUILD COPY Dockerfile* compose* Gemfile* /data/app/
ONBUILD RUN try-bundle-install

ONBUILD COPY Dockerfile* compose* requirements.txt* /data/app/
ONBUILD RUN try-pip-install

# Finally, copy over the main app code
ONBUILD COPY . /data/app

# Friendly warning if you've changed configuration files from default
ONBUILD RUN warn-about-overrides
