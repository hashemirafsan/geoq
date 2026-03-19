FROM elixir:1.17-otp-27

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    gdal-bin \
    git \
    libgdal-dev \
    libnetcdf-dev \
    netcdf-bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ENV MIX_ENV=dev

# Keep cache locations stable for Docker volumes.
ENV HEX_HOME=/root/.hex
ENV MIX_HOME=/root/.mix

RUN mix local.hex --force && mix local.rebar --force

CMD ["bash"]
