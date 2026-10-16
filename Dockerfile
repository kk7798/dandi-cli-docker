FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && python -m pip install --upgrade pip setuptools wheel \
    && python -m pip install --no-cache-dir dandi \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /input /output /work

COPY entrypoint.sh /usr/local/bin/dandi-entrypoint
COPY upload_workflow.py /usr/local/bin/dandi-upload-workflow.py
RUN chmod +x /usr/local/bin/dandi-entrypoint

WORKDIR /
ENTRYPOINT ["/usr/local/bin/dandi-entrypoint"]
