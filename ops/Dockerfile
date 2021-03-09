# FIXME: Loosen Elixir Docker image requirement once 
# https://github.com/gen-smtp/gen_smtp/issues/250
# and https://github.com/erlang/otp/issues/4585 have been fixed
FROM elixir:1.11.2-alpine as build
ENV MIX_ENV=prod

RUN apk add git npm build-base

COPY mix.exs mix.lock ./
COPY config .
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix ./assets
    
COPY . .
RUN npm run deploy --prefix ./assets && \
    mix phx.digest && \
    mix release

FROM elixir:1.11.2-alpine
ENV HOME=/opt/app
WORKDIR ${HOME}
COPY --from=build _build/prod/rel/keila ${HOME}
RUN mkdir -p ${HOME} && \
    adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default && \
    chown -R 1001:0 ${HOME}
ENTRYPOINT ["/opt/app/bin/keila"]
CMD "start"