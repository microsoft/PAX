# =============================================================================
# PAX Purview Audit Log Processor — container image for Azure Container Apps Jobs
# -----------------------------------------------------------------------------
# Base : Microsoft PowerShell 7.4 LTS on Ubuntu 22.04
# Adds : Microsoft.Graph (2.x), Az.Accounts, ImportExcel, ExchangeOnlineManagement
#        + Python 3 + 'orjson' for the embedded rollup post-processor
#
# This Dockerfile is fully self-contained — the PAX script is downloaded
# directly from the pinned GitHub release at build time. You do NOT need to
# clone the PAX repo. Just download THIS one file (PAX.Dockerfile).
#
# REQUIRED: --build-arg SCRIPT_VERSION=<x.y.z>  (no default; build will fail
# without it). Pick the version from https://github.com/microsoft/PAX/releases
# (e.g. 1.11.1, 1.11.2, ...).
#
# Build:
#   docker build --build-arg SCRIPT_VERSION=1.11.1 \
#       -f PAX.Dockerfile -t pax-purview:1.11.1 .
#
# Push to Azure Container Registry:
#   az acr login --name <acrName>
#   docker tag pax-purview:1.11.1 <acrName>.azurecr.io/pax-purview:1.11.1
#   docker push <acrName>.azurecr.io/pax-purview:1.11.1
# =============================================================================
FROM mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04

# REQUIRED build arg — no default. Build fails fast if not supplied.
ARG SCRIPT_VERSION
RUN test -n "$SCRIPT_VERSION" || (echo 'ERROR: --build-arg SCRIPT_VERSION=<x.y.z> is required. Example: docker build --build-arg SCRIPT_VERSION=1.11.1 -f PAX.Dockerfile -t pax-purview:1.11.1 .' >&2 && exit 1)

ENV DEBIAN_FRONTEND=noninteractive \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    PSModulePath=/root/.local/share/powershell/Modules:/usr/local/share/powershell/Modules:/opt/microsoft/powershell/7/Modules

# OS deps + Python (for embedded rollup post-processor)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl python3 python3-pip tini \
 && pip3 install --no-cache-dir orjson \
 && rm -rf /var/lib/apt/lists/*

# Required PowerShell modules. Pinned to current major lines.
RUN pwsh -NoLogo -NoProfile -Command " \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    \$ProgressPreference='SilentlyContinue'; \
    Install-Module Microsoft.Graph            -RequiredVersion 2.25.0 -Scope AllUsers -Force -AllowClobber; \
    Install-Module Az.Accounts                -RequiredVersion 3.0.4  -Scope AllUsers -Force -AllowClobber; \
    Install-Module ImportExcel                -RequiredVersion 7.8.10 -Scope AllUsers -Force -AllowClobber; \
    Install-Module ExchangeOnlineManagement   -RequiredVersion 3.6.0  -Scope AllUsers -Force -AllowClobber; \
"

WORKDIR /app

# Pull the PAX script straight from the pinned GitHub release.
# No build context required — only this Dockerfile is needed on disk.
RUN curl -fSL --retry 5 --retry-delay 2 \
        "https://github.com/microsoft/PAX/releases/download/purview-v${SCRIPT_VERSION}/PAX_Purview_Audit_Log_Processor_v${SCRIPT_VERSION}.ps1" \
        -o /app/PAX_Purview_Audit_Log_Processor.ps1 \
 && chmod 0644 /app/PAX_Purview_Audit_Log_Processor.ps1

# tini handles PID 1 + signal forwarding so Ctrl+C / SIGTERM hits pwsh cleanly.
ENTRYPOINT ["/usr/bin/tini", "--", "pwsh", "-NoLogo", "-NoProfile", "-File", "/app/PAX_Purview_Audit_Log_Processor.ps1"]

# Default to no args; the ACA Job's `command`/`args` provides per-run parameters.
CMD []
