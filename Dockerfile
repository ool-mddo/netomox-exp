FROM ruby:3.4.10-slim

WORKDIR /netomox-exp
COPY . /netomox-exp

# install required runtime packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq less \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# install ruby gems (build-essential is needed for native extensions, removed after install)
RUN --mount=type=secret,id=ghp_credential \
    apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && gem install bundler \
    && export BUNDLE_RUBYGEMS__PKG__GITHUB__COM=$(cat /run/secrets/ghp_credential) \
    && bundle install \
    && unset BUNDLE_RUBYGEMS__PKG__GITHUB__COM \
    && apt-get purge -y --auto-remove build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["rerun", "--force-polling", "bundle exec rackup -s webrick -o 0.0.0.0 -p 9292"]
