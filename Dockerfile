FROM ruby:3.1.0-slim as base

WORKDIR /netomox-exp
COPY . /netomox-exp

# gcc/make: to build native extensions (json)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc make git

# install all (production and development) ruby tools (with native extensions)
RUN gem install bundler \
    && bundle install

# install required packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq less \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["rerun", "--force-polling", "bundle exec rackup -s webrick -o 0.0.0.0 -p 9292"]
