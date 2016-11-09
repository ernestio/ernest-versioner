lint:
	bundle exec rubocop

deps:
	gem install bundle
	go get -u github.com/r3labs/verify

install:
	bundle install

test: lint
	

