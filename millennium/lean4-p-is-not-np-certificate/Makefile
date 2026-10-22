IMAGE   := lean4-pnnp
CONTAINER := lean4-pnnp-extract

.PHONY: all build run certificate clean

all: build run

build:
	docker build -t $(IMAGE) .

run:
	docker run --rm $(IMAGE)

certificate:
	@docker rm -f $(CONTAINER) 2>/dev/null || true
	@ID=$$(docker create --name $(CONTAINER) $(IMAGE)) && \
	 docker cp $$ID:/build/.lake/build/lib/lean/PNNP.olean . 2>/dev/null && \
	 echo "Extracted: PNNP.olean (kernel-checked certificate)" || \
	 echo "Certificate extraction failed — run 'make run' for details"; \
	 docker rm -f $(CONTAINER) >/dev/null

clean:
	docker rmi $(IMAGE) 2>/dev/null || true
	docker rm -f $(CONTAINER) 2>/dev/null || true
	rm -f PNNP.olean
