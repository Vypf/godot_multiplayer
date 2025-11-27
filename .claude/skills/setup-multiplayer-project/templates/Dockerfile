# Stage 1: Download Godot headless
FROM ubuntu:22.04 AS godot-download

ARG GODOT_VERSION=4.5-stable

RUN apt-get update && \
    apt-get install -y wget unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip && \
    unzip Godot_v${GODOT_VERSION}_linux.x86_64.zip && \
    chmod +x Godot_v${GODOT_VERSION}_linux.x86_64

# Stage 2: Runtime image
FROM ubuntu:22.04

ARG GODOT_VERSION=4.5-stable

RUN apt-get update && \
    apt-get install -y \
    libstdc++6 \
    ca-certificates \
    libfontconfig1 \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=godot-download /tmp/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot

WORKDIR /app
COPY --chown=root:root . /app/

RUN rm -rf /app/executables /app/logs /app/.git
RUN mkdir -p /app/logs

# Import des assets Godot - génère .godot/imported/ et .godot/uid_cache.bin
# IMPORTANT: Utiliser --import au lieu de --editor --quit-after 2
# car seul --import génère le fichier uid_cache.bin nécessaire au runtime
# (voir godotengine/godot#107695)
RUN /usr/local/bin/godot --headless --path /app --import || true

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/godot", "--headless", "--path", "/app"]
CMD ["server_type=room"]
