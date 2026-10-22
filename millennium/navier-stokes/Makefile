.PHONY: build run clean

IMAGE := rocq-cve-poc-22287-ns

build:
	docker build -t $(IMAGE) .

run: build
	docker run --rm $(IMAGE)

clean:
	docker rmi $(IMAGE) 2>/dev/null || true
