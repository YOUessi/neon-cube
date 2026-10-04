SHELL := /usr/bin/env bash

.PHONY: bootstrap validate test ci

bootstrap:
	./scripts/bootstrap_godot.sh

validate:
	./scripts/validate_project.sh

test:
	./scripts/run_tests.sh

ci: validate test
