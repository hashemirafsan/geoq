SHELL := /bin/bash

.PHONY: docker-build shell deps compile test cover format lint clean-cache data-check

docker-build:
	docker compose build

shell:
	docker compose run --rm dev

deps:
	docker compose run --rm dev bash -lc "mix deps.get"

compile:
	docker compose run --rm dev bash -lc "mix compile"

test:
	docker compose run --rm test

cover:
	docker compose run --rm test bash -lc "mix deps.get && mix test --cover"

format:
	docker compose run --rm dev bash -lc "mix format"

lint:
	docker compose run --rm dev bash -lc "mix credo --strict"

clean-cache:
	docker compose down -v

data-check:
	docker compose run --rm dev bash -lc "gdalinfo data/grc_t_60_2015_CN_100m_R2024B_v1.tif >/dev/null && ncdump -h data/HWD_EU_health_rcp85_mean_v1.0.nc >/dev/null && echo 'GeoTIFF and NetCDF tools can read sample data'"
