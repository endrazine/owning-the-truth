IMAGE ?= rocqsploit
DOCKER ?= docker

.PHONY: all build run clean

all: build run

build:
	$(DOCKER) build --tag $(IMAGE) .

run:
	$(DOCKER) run --rm $(IMAGE)

clean:
	$(DOCKER) image rm $(IMAGE)
