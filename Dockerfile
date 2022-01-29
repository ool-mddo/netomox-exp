FROM ruby:3.1.0-slim

# suppress `Calling `DidYouMean::SPELL_CHECKERS.merge!` warning
ENV RUBYOPT='--disable-did_you_mean'
ENV NETOMOX_LOG_LEVEL=warn
ENV TOPOLOGY_BUILDER_LOG_LEVEL=warn

WORKDIR /netomox-exp
COPY . /netomox-exp

# install required packages
RUN apt-get update \
    && apt-get install -y git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# ruby tools
RUN gem install bundler \
    && bundle install
