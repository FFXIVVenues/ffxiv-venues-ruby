FROM ruby:4.0.1
WORKDIR /usr/src/app

COPY . .
RUN bundle install

CMD [ "ruby", "./main.rb" ]