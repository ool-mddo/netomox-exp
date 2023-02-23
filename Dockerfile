# multi-stage build
# ruby-slim -+-> base -+-> develop     ...install all (production and development) gems
#            |         |
#            |         +-> build -+    ...install production (without development) gems
#            |                    | copy
#            |                    V
#            +-----------------> production

FROM ruby:3.1.0-slim as base

WORKDIR /netomox-exp
COPY . /netomox-exp

# gcc/make: to build native extensions (json)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc make git

FROM base as develop

# install all (production and development) ruby tools (with native extensions)
RUN gem install bundler \
    && bundle install

# install required packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq less csvtool bsdextrautils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["rerun", "--force-polling", "rackup -s webrick -o 0.0.0.0 -p 9292"]

FROM base as build

# install production ruby tools (with native extensions)
RUN gem install bundler \
    && bundle config set --local without 'development' \
    && bundle install

FROM ruby:3.1.0-slim as production

# suppress `Calling `DidYouMean::SPELL_CHECKERS.merge!` warning
ENV RUBYOPT='--disable-did_you_mean'
# set default log level
ENV NETOMOX_LOG_LEVEL=warn
ENV TOPOLOGY_BUILDER_LOG_LEVEL=warn

WORKDIR /netomox-exp
# copy netomox-exp (including Gemfiles.lock)
COPY --from=build /netomox-exp /netomox-exp
# copy installed gems (with native extensions)
COPY --from=build /usr/local /usr/local

# install required packages
#   bsdextrautils: for `column` command
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq less csvtool bsdextrautils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["rackup", "-s", "webrick", "-o", "0.0.0.0", "-p", "9292"]
