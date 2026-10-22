IMAGE   := lean4-pnp
CONTAINER := lean4-pnp-extract

.PHONY: all build run certificate clean

all: build run

build:
	docker build -t $(IMAGE) .

run:
	docker run --rm $(IMAGE)

certificate:
	@docker rm -f $(CONTAINER) 2>/dev/null || true
	@ID=$$(docker create --name $(CONTAINER) $(IMAGE)) && \
	 docker cp $$ID:/build/.lake/build/lib/lean/PNP.olean . 2>/dev/null && \
	 echo "Extracted: PNP.olean (kernel-checked certificate)" || \
	 echo "Certificate extraction failed — run 'make run' for details"; \
	 docker rm -f $(CONTAINER) >/dev/null

clean:
	docker rmi -f $(IMAGE) 2>/dev/null || true
	rm -f PNP.olean
