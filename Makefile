lint:
	bundle exec rubocop

deps:
	gem install bundle
	go get -u github.com/r3labs/verify
	go get -u github.com/r3labs/composable

install:
	bundle install

test: lint
	

