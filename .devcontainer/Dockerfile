ARG ELIXIR_VERSION="1.15.8"
FROM elixir:${ELIXIR_VERSION}

# Install system dependencies including liblttng-ust1 for Erlang tracing
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        build-essential \
        cmake \
        git \
        curl \
        ca-certificates \
        liblttng-ust1 \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install Elixir and Phoenix
ARG PHOENIX_VERSION="1.7.10"
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix archive.install --force hex phx_new ${PHOENIX_VERSION}

# Install dprint
RUN curl -fsSL https://dprint.dev/install.sh | sh \
    && mv ~/.dprint/bin/dprint /usr/local/bin

# The user setup will be handled by the common-utils feature