# REPORTER = progress
# REPORTER = list
REPORTER = spec
# REPORTER = dot

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

.PHONY: test test-spec test-w
