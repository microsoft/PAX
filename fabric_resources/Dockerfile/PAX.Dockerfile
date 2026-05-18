# =============================================================================
# PAX Purview Audit Log Processor — container image for Azure Container Apps Jobs
# -----------------------------------------------------------------------------
# Base : Microsoft PowerShell 7.4 LTS on Ubuntu 22.04
# Adds : Microsoft.Graph (2.x), Az.Accounts, ExchangeOnlineManagement
#        + Python 3 + 'orjson' (fast JSON), 'pyarrow' + 'deltalake' (Fabric Lakehouse
#        Delta-table writes)
#
# The image supports the per-data-type destination model: each stream
# (Purview audit, EntraUsers, Agent 365 catalog, run log) routes
# through its own `-OutputPath*` / `-Append*` switch pair and storage tier is
# inferred from each path's form (drive-rooted = Local, sharepoint.com URL =
# SharePoint, onelake.dfs.fabric.microsoft.com URL = Fabric). The `deltalake`
# Python package is preinstalled below so the auto-install step inside PAX is
# a no-op at runtime on this image (offline / locked-down hosts therefore work
# without additional setup). UNC paths are rejected by PAX on every destination
# switch — no container-side support needed.
#
# This Dockerfile is fully self-contained — the PAX script is downloaded
# directly from the pinned GitHub release at build time. You do NOT need to
# clone the PAX repo. Just download THIS one file (PAX.Dockerfile).
#
# REQUIRED: --build-arg SCRIPT_VERSION=<x.y.z>  (no default; build will fail
# without it). Pick the version from https://github.com/microsoft/PAX/releases.
#
# OPTIONAL supply-chain verification:
#   --build-arg SCRIPT_SHA256=<sha256-digest>
# When supplied, the downloaded PAX_Purview_Audit_Log_Processor_v${SCRIPT_VERSION}.ps1
# is verified against this digest with `sha256sum -c -`; the build fails fast on
# mismatch. When omitted, the build emits a clear warning that verification is
# SKIPPED and continues.
#
# Pick the digest that matches how you consume the script:
#   1. Stock script (unmodified vendor release) — use the digest published in
#      the GitHub release notes / sidecar `.sha256` file for the version you
#      pinned via SCRIPT_VERSION. This proves the curl pulled the exact bytes
#      Microsoft shipped (defends against tampered mirrors / wrong-version pulls).
#   2. Customized script (you forked, patched, or edited the PAX script) —
#      first download the official release, customize it, then compute your
#      own digest from the edited file and pin to that. This is the recommended
#      path: the image now refuses to build if the script ever drifts from
#      your approved customized copy. NOTE: pinning to the stock vendor digest
#      after editing will (correctly) fail the build — use your own digest.
#   3. Dev / inner-loop iteration — omit the arg, accept the WARNING, do not
#      ship the resulting image to production.
#
# Compute the digest:
#   Linux / macOS :  sha256sum PAX_Purview_Audit_Log_Processor_v<x.y.z>.ps1
#   Windows pwsh  :  (Get-FileHash <file> -Algorithm SHA256).Hash.ToLower()
#
# Build (with verification — recommended for any non-dev image):
#   docker build --build-arg SCRIPT_VERSION=<x.y.z> \
#       --build-arg SCRIPT_SHA256=<digest> \
#       -f PAX.Dockerfile -t pax-purview:<x.y.z> .
#
# Build (without verification — dev only):
#   docker build --build-arg SCRIPT_VERSION=<x.y.z> \
#       -f PAX.Dockerfile -t pax-purview:<x.y.z> .
#
# Push to Azure Container Registry:
#   az acr login --name <acrName>
#   docker tag pax-purview:<x.y.z> <acrName>.azurecr.io/pax-purview:<x.y.z>
#   docker push <acrName>.azurecr.io/pax-purview:<x.y.z>
# =============================================================================
FROM mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04

# REQUIRED build arg — no default. Build fails fast if not supplied.
ARG SCRIPT_VERSION
RUN test -n "$SCRIPT_VERSION" || (echo 'ERROR: --build-arg SCRIPT_VERSION=<x.y.z> is required. Example: docker build --build-arg SCRIPT_VERSION=<x.y.z> -f PAX.Dockerfile -t pax-purview:<x.y.z> .' >&2 && exit 1)

# OPTIONAL supply-chain verification. See header for the three-mode picker
# (stock / customized / dev). Build fails on mismatch when supplied; emits a
# clear WARNING and continues when empty. Non-dev images SHOULD set this —
# customized images should pin to their own digest, not the stock vendor digest.
ARG SCRIPT_SHA256=""

ENV DEBIAN_FRONTEND=noninteractive \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    PAX_NONINTERACTIVE=1 \
    PAX_BOOTSTRAP_LOG_DIR=/pax-logs \
    PSModulePath=/usr/local/share/powershell/Modules:/opt/microsoft/powershell/7/Modules

# Durable bootstrap-log directory.
# PAX opens its run log here BEFORE any parameter validation runs, so any
# pre-flight / auth / param-validation failure leaves a readable log on disk.
# Declared as a VOLUME so operators can mount Azure Files at this path on
# Azure Container Instances / Container Apps Jobs — the bootstrap log then
# survives container exit and is retrievable from the share without spinning
# a replacement container instance (cost concern in ACI). When the run
# completes the bootstrap log is Move-Item'd to its final location (local
# scratch + uploaded to SharePoint/Fabric for remote-tier runs, or the
# operator-supplied -OutputPathLog destination); the bootstrap source file is
# removed by the move, the durable directory itself remains for the next run.
RUN mkdir -p /pax-logs && chmod 0777 /pax-logs
VOLUME ["/pax-logs"]

# OS deps + Python (for embedded rollup post-processor and Fabric Delta writes)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl python3 python3-pip tini \
 && pip3 install --no-cache-dir orjson 'pyarrow>=14' 'deltalake>=0.15' \
 && rm -rf /var/lib/apt/lists/*

# Required PowerShell modules. Pinned to current major lines.
RUN pwsh -NoLogo -NoProfile -Command " \
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
    \$ProgressPreference='SilentlyContinue'; \
    Install-Module Microsoft.Graph            -RequiredVersion 2.25.0 -Scope AllUsers -Force -AllowClobber; \
    Install-Module Az.Accounts                -RequiredVersion 3.0.4  -Scope AllUsers -Force -AllowClobber; \
    Install-Module ExchangeOnlineManagement   -RequiredVersion 3.6.0  -Scope AllUsers -Force -AllowClobber; \
"

WORKDIR /app

# Pull the PAX script straight from the pinned GitHub release.
# No build context required — only this Dockerfile is needed on disk.
# When SCRIPT_SHA256 is supplied the download is verified against the digest
# (build fails on mismatch). When omitted, a clear WARNING is emitted that
# verification is SKIPPED. See header for the stock / customized / dev modes.
RUN curl -fSL --retry 5 --retry-delay 2 \
        "https://github.com/microsoft/PAX/releases/download/purview-v${SCRIPT_VERSION}/PAX_Purview_Audit_Log_Processor_v${SCRIPT_VERSION}.ps1" \
        -o /app/PAX_Purview_Audit_Log_Processor.ps1 \
 && if [ -n "$SCRIPT_SHA256" ]; then \
        echo "${SCRIPT_SHA256}  /app/PAX_Purview_Audit_Log_Processor.ps1" | sha256sum -c - \
            || (echo "ERROR: SHA-256 verification FAILED for downloaded PAX script. Expected: ${SCRIPT_SHA256}" >&2 && exit 1); \
        echo "PAX script SHA-256 verified."; \
    else \
        echo "WARNING: SCRIPT_SHA256 build-arg not supplied — supply-chain verification SKIPPED. Use only for dev images." >&2; \
    fi \
 && chmod 0644 /app/PAX_Purview_Audit_Log_Processor.ps1

# Create an unprivileged system user and drop privileges before ENTRYPOINT.
# PowerShell modules are installed to /usr/local/share/powershell/Modules (-Scope AllUsers,
# world-readable) and Python packages are pip3-installed system-wide, so dropping to a
# non-root UID does not affect runtime resolution. PAX writes scratch files to /tmp
# (world-writable), bootstrap logs to /pax-logs (world-writable, declared VOLUME for
# durable mounting), and run output to remote URLs (SharePoint / OneLake / Fabric).
RUN groupadd --system --gid 10001 pax \
 && useradd  --system --uid 10001 --gid 10001 \
             --home-dir /home/pax --create-home --shell /usr/sbin/nologin pax \
 && chown -R pax:pax /app /home/pax /pax-logs
USER pax

# tini handles PID 1 + signal forwarding so Ctrl+C / SIGTERM hits pwsh cleanly.
ENTRYPOINT ["/usr/bin/tini", "--", "pwsh", "-NoLogo", "-NoProfile", "-File", "/app/PAX_Purview_Audit_Log_Processor.ps1"]

# Default to no args; the ACA Job's `command`/`args` provides per-run parameters.
CMD []
