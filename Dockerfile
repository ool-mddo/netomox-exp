FROM ruby:3.1.0-slim

ARG APP_PATH="/myapp"
RUN mkdir $APP_PATH
WORKDIR $APP_PATH
COPY . $APP_PATH
RUN apt-get update \
    && apt-get install -y python3-pip git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir -r configs/requirements.txt
RUN gem install bundler \
    && bundle install
