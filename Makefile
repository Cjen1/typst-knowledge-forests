CLI ?= cargo run --quiet --release -- build

.PHONY: build graph render clean

build:
	$(CLI)

graph:
	cargo run --quiet --release -- graph

render:
	cargo run --quiet --release -- render

clean:
	rm -rf generated dist target
