FROM ruby:3.1.0

ARG APP_PATH="/myapp"
RUN mkdir $APP_PATH
WORKDIR $APP_PATH
COPY . $APP_PATH
RUN apt-get update && apt-get install -y  python3-pip
RUN pip3 install -r configs/requirements.txt
RUN gem  install bundler 
RUN bundle install
