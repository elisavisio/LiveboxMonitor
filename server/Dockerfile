# ==============================================================================
# Livebox Monitor Server — Multi-stage Docker build (Dart Frog + SQLite + Vault)
# Build from repository root:
#   docker build -f server/Dockerfile -t livebox-monitor-server .
# Or via docker compose from server/:
#   docker compose up -d --build
# ==============================================================================

FROM dart:stable AS build

WORKDIR /workspace

# Install Dart Frog CLI
RUN dart pub global activate dart_frog_cli
ENV PATH="/root/.pub-cache/bin:${PATH}"

# Copy shared Livebox client package (reused from flutter_app)
COPY packages/livebox_client /workspace/packages/livebox_client

# Copy server source
COPY server /workspace/server

# Clean any host caches copied in the build context, then build Dart Frog production bundle
RUN rm -rf /workspace/packages/livebox_client/.dart_tool \
           /workspace/server/.dart_tool \
           /workspace/server/build \
           /workspace/server/data

WORKDIR /workspace/server
RUN dart pub get
RUN dart_frog build

# Compile production server to native AOT executable
WORKDIR /workspace/server/build
RUN dart pub get --offline || dart pub get
RUN dart compile exe bin/server.dart -o /workspace/server_bin

# ==============================================================================
# Minimal runtime image with libsqlite3 and non-root user
# ==============================================================================
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/lib/*-linux-gnu/libsqlite3.so.0 /usr/lib/libsqlite3.so \
    && ldconfig

# Create non-root user and persistent /data volume directory
RUN useradd -m -u 10001 -s /usr/sbin/nologin lbm \
    && mkdir -p /app /data \
    && chown -R lbm:lbm /app /data

WORKDIR /app

COPY --from=build /workspace/server_bin /app/server
COPY --from=build /workspace/server/public /app/public
RUN chown -R lbm:lbm /app

USER lbm

ENV PORT=8080 \
    DATA_DIR=/data

EXPOSE 8080
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/api/health || exit 1

ENTRYPOINT ["/app/server"]
