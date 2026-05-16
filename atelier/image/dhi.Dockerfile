FROM dhi.io/debian-base:trixie-debian13@sha256:79ea7f22d1b7e3f73b0988258b62bcbf73da44f0d82476fbb95d811130168e55 AS final-stage

LABEL org.opencontainers.image.authors="Karim Zouine <mails.karimzouine@gmail.com>" \
      org.opencontainers.image.vendor="Karim Zouine" \
      org.opencontainers.image.title="imgcompress - High Performance Image Compression & Background Removal" \
      org.opencontainers.image.description="Self-hosted, privacy-first tool for image compression, conversion (HEIC/WebP/PDF), and background removal using local AI. Supports 70+ formats." \
      org.opencontainers.image.url="https://github.com/karimz1/imgcompress" \
      org.opencontainers.image.source="https://github.com/karimz1/imgcompress" \
      org.opencontainers.image.documentation="https://github.com/karimz1/imgcompress" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

ENV VIRTUAL_ENV=/container/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV U2NET_HOME=/container/.u2net

WORKDIR /container

COPY --from=docker.io/thanhzeus2016/imgcompress-artifact-carrier:0.6.1@sha256:80fee002b97fd9c7ba65aa53c39593d4ede7b48202ff8885ef8ec85ccc90cad5 /dpkg-export/ /
COPY --from=docker.io/thanhzeus2016/imgcompress-artifact-carrier:0.6.1@sha256:80fee002b97fd9c7ba65aa53c39593d4ede7b48202ff8885ef8ec85ccc90cad5 /container /container
USER nonroot

EXPOSE 5000

# Constraint: The runtime hardened image lacks a shell (/bin/sh).
# We execute the healthcheck via python directly.
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["python", "/container/healthcheck.py"]

ENTRYPOINT ["/usr/bin/dumb-init", "--", "python", "/container/entrypoint.py"]