# REPORTER = progress
# REPORTER = list
# REPORTER = spec
# REPORTER = dot

test-full:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require ./coffee-coverage.js \
		--reporter dot \
		--ui tdd \
		&& ./node_modules/.bin/coffeelint test/* scripts/* lib/* index.coffee \
		&& ./node_modules/.bin/istanbul report

test:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter dot \
		--ui tdd

test-spec:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter spec \
		--ui tdd

test-w:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--reporter min \
		--ui tdd \
		--watch

test-coverage:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require ./coffee-coverage.js \
		--reporter dot \
		--ui tdd \
		&& ./node_modules/.bin/istanbul report lcovonly

test-cov:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--compilers coffee:coffee-script \
		--require ./coffee-coverage.js \
		--reporter dot \
		--ui tdd \
		&& ./node_modules/.bin/istanbul report

lint:
	@NODE_ENV=test ./node_modules/.bin/coffeelint test/* scripts/* lib/* index.coffee

.PHONY: test test-spec test-w test-coverage test-cov test-full lint
