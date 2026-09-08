FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y curl jq bash && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

CMD ["bash"]
