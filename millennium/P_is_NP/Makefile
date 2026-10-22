.PHONY: build run clean

IMAGE := rocq-22287-sat-in-p

build:
	docker build -t $(IMAGE) .

run: build
	docker run --rm $(IMAGE)

clean:
	docker rmi $(IMAGE) 2>/dev/null || true
