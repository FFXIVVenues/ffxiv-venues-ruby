FROM ruby:3.2.2
WORKDIR /usr/src/app

COPY . .
RUN bundle install

CMD [ "ruby", "./main.rb" ]