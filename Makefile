IMAGE ?= yourdockerhubuser/auspost-devops-demo
VERSION ?= local

.PHONY: install test lint security run docker-build docker-run k8s-local
install:
	python -m pip install -r requirements-dev.txt

test:
	pytest

lint:
	ruff check app tests

security:
	bandit -r app -c pyproject.toml
	pip-audit -r requirements.txt

run:
	APP_VERSION=$(VERSION) uvicorn app.main:app --host 0.0.0.0 --port 8080

docker-build:
	docker build --build-arg APP_VERSION=$(VERSION) -t $(IMAGE):$(VERSION) .

docker-run:
	docker run --rm -p 8080:8080 -e APP_VERSION=$(VERSION) $(IMAGE):$(VERSION)

k8s-local:
	kubectl apply -k k8s/overlays/local
