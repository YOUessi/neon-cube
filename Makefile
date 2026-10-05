SHELL := /usr/bin/env bash

.PHONY: bootstrap validate test build ci

bootstrap:
	./scripts/bootstrap_godot.sh

validate:
	./scripts/validate_project.sh

test:
	./scripts/run_tests.sh

build:
	./scripts/build_release.sh

ci: validate test build
