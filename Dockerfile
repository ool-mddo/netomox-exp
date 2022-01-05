FROM ruby:2.7.0

RUN mkdir /myapp
WORKDIR /myapp
COPY . /myapp
RUN apt-get update && apt-get install -y  python3-pip
RUN pip3 install -r configs/requirements.txt
RUN bundle install --path=vendor/bundle
