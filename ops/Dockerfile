FROM elixir:1.11-alpine as build
ENV MIX_ENV=prod
COPY . .
RUN apk add git npm build-base && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    cd assets && \
    npm ci && \
    npm run deploy && \
    cd .. && \
    mix phx.digest && \
    mix release

FROM elixir:1.11-alpine
ENV HOME=/opt/app
WORKDIR ${HOME}
COPY --from=build _build/prod/rel/keila ${HOME}
RUN mkdir -p ${HOME} && \
    adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default && \
    chown -R 1001:0 ${HOME}
ENTRYPOINT ["/opt/app/bin/keila"]
