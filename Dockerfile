FROM ruby:3.1.0-slim

WORKDIR /netomox-exp
COPY . /netomox-exp

# gcc/make: to build native extensions (json)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc make \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# install all (production and development) ruby tools (with native extensions)
RUN --mount=type=secret,id=ghp_credential \
    gem install bundler \
    && export BUNDLE_RUBYGEMS__PKG__GITHUB__COM=$(cat /run/secrets/ghp_credential) \
    && bundle install \
    && unset BUNDLE_RUBYGEMS__PKG__GITHUB__COM

# install required packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq less \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["rerun", "--force-polling", "bundle exec rackup -s webrick -o 0.0.0.0 -p 9292"]
