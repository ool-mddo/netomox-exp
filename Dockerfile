FROM ruby:3.1.0-slim as build

WORKDIR /netomox-exp
COPY . /netomox-exp

# gcc/make: to build native extensions (json)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc make git

# install ruby tools (with native extensions)
RUN gem install bundler \
    && bundle config set --local without 'development' \
    && bundle install

# multi-stage build
# it need to install native-extensions but do not need to install build tools (gcc/make)
FROM ruby:3.1.0-slim as production

# suppress `Calling `DidYouMean::SPELL_CHECKERS.merge!` warning
ENV RUBYOPT='--disable-did_you_mean'
# set default log level
ENV NETOMOX_LOG_LEVEL=warn
ENV TOPOLOGY_BUILDER_LOG_LEVEL=warn

WORKDIR /netomox-exp
COPY . /netomox-exp

# copy installed gems (with native extensions)
COPY --from=build /usr/local /usr/local

# install required packages
#   bsdextrautils: for `column` command
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq less csvtool bsdextrautils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
