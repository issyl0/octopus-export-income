FROM ruby:3.1.2

WORKDIR /octopus-export-income
COPY . /octopus-export-income

RUN bundle install

ENTRYPOINT ["ruby", "main.rb"]
