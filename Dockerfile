FROM ruby:3.1.0-slim

# default
ARG APP_PATH="/myapp"
# suppress `Calling `DidYouMean::SPELL_CHECKERS.merge!` warning
ENV RUBYOPT='--disable-did_you_mean'
ENV NETOMOX_LOG_LEVEL=warn
ENV TOPOLOGY_BUILDER_LOG_LEVEL=warn

WORKDIR $APP_PATH
COPY . $APP_PATH

# install required packages
RUN apt-get update \
    && apt-get install -y python3-pip git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# python tools
RUN pip3 install --no-cache-dir -r configs/requirements.txt
# ruby tools
RUN gem install bundler \
    && bundle install
