FROM elixir:1.18-alpine AS build

ARG WITH_EXTRA=0
ARG KEILA_CLOUD=0
ARG KEILA_CLOUD_LICENSE

ENV MIX_ENV=prod

RUN apk add git npm build-base openssl cmake

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

FROM elixir:1.15-alpine
ENV HOME=/opt/app

WORKDIR ${HOME}
COPY --from=build _build/prod/rel/keila ${HOME}
RUN apk add openssl
RUN mkdir -p ${HOME} && \
    adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default && \
    chown -R 1001:0 ${HOME}
ENTRYPOINT ["/opt/app/bin/keila"]
CMD ["start"]

ARG PORT=4000
ENV PORT=${PORT}
EXPOSE ${PORT}/tcp
