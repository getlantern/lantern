COFFEE = ./node_modules/coffee-script/bin/coffee
UGLIFY = ./node_modules/uglify-js/bin/uglifyjs

setup:
	npm install

build: compile minify

compile:
	$(COFFEE) --compile waypoints.coffee shortcuts/*/*.coffee

minify:
	$(UGLIFY) -m --comments all -o waypoints.min.js waypoints.js
	$(UGLIFY) -m --comments all  -o shortcuts/infinite-scroll/waypoints-infinite.min.js shortcuts/infinite-scroll/waypoints-infinite.js
	$(UGLIFY) -m --comments all  -o shortcuts/sticky-elements/waypoints-sticky.min.js shortcuts/sticky-elements/waypoints-sticky.js

.PHONY: setup build compile minify