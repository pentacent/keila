# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# This file is based on these images:
#
#   - Build image
#   - https://hub.docker.com/r/hexpm/elixir/tags?name=1.18.4-erlang-27.3.4.3-ubuntu-noble
#
#   - Release image
#   - https://hub.docker.com/r/hexpm/elixir/tags?name=noble-20251001
#
#   - Dockerfile
#   - Eg: hexpm/elixir:1.18.4-erlang-27.3.4-ubuntu-noble-20251001
#
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.3
ARG UBUNTU_VERSION=noble-20251001

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"

ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ARG WITH_EXTRA=0
ARG KEILA_CLOUD=0
ARG KEILA_CLOUD_LICENSE

ENV MIX_ENV=prod

# Use Bash
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install locales - via https://hub.docker.com/_/ubuntu
RUN apt-get update \
    && apt-get install -y locales locales-all \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Install build dependencies
RUN apt-get update \
    && apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Node https://github.com/nodesource/distributions#installation-instructions
RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh \
    && bash nodesource_setup.sh \
    && apt-get update \
    && apt-get install -y \
    nodejs \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/* \
    # smoke tests
    && node --version \
    && npm --version

# prepare build dir
WORKDIR /app

COPY mix.exs mix.lock ./
COPY config .
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix ./assets

COPY . .
RUN mix deps.clean mime --build && \
    mix assets.deploy && \
    mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS deployer

# Use Bash
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
# For tzdata
ENV DEBIAN_FRONTEND=noninteractive
# set runner ENV
ENV MIX_ENV="prod"

# Install locales - via https://hub.docker.com/_/ubuntu
RUN apt-get update \
    && apt-get install -y locales locales-all \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

# Timezone
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime

# Add keila user & group, home directory (-m) and app directory
RUN groupadd -r keila \
    && useradd -r -m -g keila keila \
    && mkdir /app \
    && chown -R keila:keila /app
WORKDIR "/app"

# Only copy the final release from the build stage
COPY --from=builder --chown=keila:keila /app/_build/${MIX_ENV}/rel/keila ./

# Update base
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/opt/app/bin/keila"]
CMD ["start"]

ARG PORT=4000
ENV PORT=${PORT}
EXPOSE ${PORT}/tcp
