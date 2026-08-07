# syntax=docker/dockerfile:1

# sniffly - Claude Code analytics dashboard (https://github.com/chiphuyen/sniffly)
#
# Build:  docker build -t sniffly .
# Run:    docker run --rm -p 8081:8081 \
#           -v "$HOME/.claude/projects:/home/sniffly/.claude/projects:ro" \
#           -v sniffly-cache:/home/sniffly/.sniffly \
#           sniffly

ARG PYTHON_VERSION=3.12
ARG SNIFFLY_VERSION=

# ---------------------------------------------------------------- build stage
FROM python:${PYTHON_VERSION}-alpine AS builder
ARG SNIFFLY_VERSION

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_ROOT_USER_ACTION=ignore

# --only-binary=:all: makes the build fail loudly if a dep has no musl wheel,
# instead of silently needing a toolchain we don't ship.
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --no-compile --only-binary=:all: \
      "sniffly${SNIFFLY_VERSION:+==${SNIFFLY_VERSION}}"

# Strip what never runs: build tooling, bundled tests, and the ~70MB of botocore
# service definitions for AWS APIs sniffly never touches (it only speaks S3, to
# Cloudflare R2, and only for the optional dashboard-sharing feature).
RUN cd "$(/opt/venv/bin/python -c 'import site; print(site.getsitepackages()[0])')" \
 && rm -rf pip pip-*.dist-info setuptools setuptools-*.dist-info pkg_resources _distutils_hack \
 && rm -f /opt/venv/bin/pip* /opt/venv/bin/activate* /opt/venv/bin/Activate.ps1 \
 && (cd botocore/data && ls | grep -vxE 's3|sts|endpoints.json|partitions.json|sdk-default-configuration.json|_retry.json' | xargs -r rm -rf) \
 && find . -name '__pycache__' -type d -prune -exec rm -rf {} + \
 && find . -name '*.dist-info' -type d -exec rm -rf {}/RECORD {}/licenses \; 2>/dev/null || true

# Trim the interpreter itself: no dev headers, static lib, test suite or GUI.
RUN rm -rf /usr/local/lib/python*/test /usr/local/lib/python*/idlelib \
           /usr/local/lib/python*/ensurepip /usr/local/lib/python*/lib2to3 \
           /usr/local/lib/python*/config-* /usr/local/include/python* \
           /usr/local/lib/libpython*.a /usr/local/share/man /usr/local/share/doc \
 && find /usr/local/lib/python* -name '__pycache__' -type d -prune -exec rm -rf {} +

# -------------------------------------------------------------- runtime stage
FROM alpine:3.21
ARG PYTHON_VERSION

# Only the shared libs CPython links against; the interpreter comes from builder.
RUN apk add --no-cache libffi libbz2 xz-libs sqlite-libs readline ncurses-libs tzdata \
 && adduser -D -u 1000 sniffly

# Note: the stdlib is copied to an explicit destination path — a glob source
# would splat its contents straight into /usr/local/lib and break `encodings`.
COPY --from=builder /usr/local/bin/python* /usr/local/bin/
COPY --from=builder /usr/local/lib/libpython3* /usr/local/lib/
COPY --from=builder /usr/local/lib/python${PYTHON_VERSION} /usr/local/lib/python${PYTHON_VERSION}/
COPY --from=builder /opt/venv /opt/venv

# Must exist in the image, owned by the runtime user: Docker seeds a new named
# volume's ownership from the image path it covers, so without this a
# `-v sniffly-cache:/home/sniffly/.sniffly` mount lands as root:root and sniffly
# dies writing config.json.
RUN mkdir -p /home/sniffly/.sniffly && chown -R sniffly:sniffly /home/sniffly

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8081 \
    AUTO_BROWSER=false

USER sniffly
WORKDIR /home/sniffly
EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,os; urllib.request.urlopen(f\"http://127.0.0.1:{os.environ['PORT']}/\").read(1)"

ENTRYPOINT ["sniffly"]
CMD ["init", "--no-browser"]
