SHELL := /bin/bash

.PHONY: docker-build shell deps compile build-escript test cover format format-check lint ci prepare-test-fixtures acceptance-smoke release-local clean-cache data-check

docker-build:
	docker compose build

shell:
	docker compose run --rm dev

deps:
	docker compose run --rm dev bash -lc "bash scripts/ci/deps_get_retry.sh"

compile:
	docker compose run --rm dev bash -lc "bash scripts/ci/deps_get_retry.sh && mix compile"

build-escript:
	docker compose run --rm dev bash -lc "bash scripts/ci/deps_get_retry.sh && mix escript.build"

test:
	docker compose run --rm test bash -lc "bash scripts/prepare_test_fixtures.sh && bash scripts/ci/deps_get_retry.sh && mix test --cover"

cover:
	docker compose run --rm test bash -lc "bash scripts/prepare_test_fixtures.sh && bash scripts/ci/deps_get_retry.sh && mix test --cover"

format:
	docker compose run --rm dev bash -lc "mix format"

format-check:
	docker compose run --rm dev bash -lc "mix format --check-formatted"

lint:
	docker compose run --rm dev bash -lc "bash scripts/ci/deps_get_retry.sh && mix credo --strict"

prepare-test-fixtures:
	docker compose run --rm dev bash -lc "bash scripts/prepare_test_fixtures.sh"

acceptance-smoke:
	docker compose run --rm dev bash -lc "bash scripts/prepare_test_fixtures.sh && bash scripts/ci/deps_get_retry.sh && mix escript.build && GEOQ_BIN=./geoq bash scripts/acceptance/macos_user_journey.sh"

release-local:
	bash scripts/release/local_release.sh $(VERSION)

ci:
	docker compose build && $(MAKE) format-check && $(MAKE) lint && $(MAKE) test

clean-cache:
	docker compose down -v

data-check:
	docker compose run --rm dev bash -lc "bash scripts/prepare_test_fixtures.sh && gdalinfo data/fixture_small.tif >/dev/null && ncdump -h data/HWD_EU_health_rcp85_mean_v1.0.nc >/dev/null && echo 'GeoTIFF and NetCDF tools can read sample data'"
