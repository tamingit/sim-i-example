# code-server (VS Code in the browser) for Sim i's developer, with Sim i's extension, which comes from the Sim i
# image (SIM_I_IMAGE). compose.yml builds it. It opens /source, and saving a file there compiles it on Sim i.

ARG SIM_I_IMAGE=ghcr.io/tamingit/sim-i:prod
FROM ${SIM_I_IMAGE} AS sim-i

FROM codercom/code-server:4.145.0

# The uid and gid that own the source folder on the host, which code-server's user takes, so its files stay theirs.
ARG SIM_I_UID=1000
ARG SIM_I_GID=1000

USER root
RUN groupmod -o -g "$SIM_I_GID" coder && usermod -o -u "$SIM_I_UID" -g "$SIM_I_GID" coder && chown -R coder:coder /home/coder
# No sudo: whoever uses code-server stays an ordinary user in this container.
RUN rm -f /etc/sudoers.d/nopasswd \
    # /source is a bind mount from the host, owned by whoever owns it there: git works on it anyway.
    && git config --system safe.directory /source \
    && mkdir -p /source && chown coder:coder /source
COPY --from=sim-i /opt/sim-i/vscode-extension /opt/sim-i/extension
# Run as the coder user at each start, before code-server (the base image's entrypoint runs ${ENTRYPOINTD}).
COPY --chmod=755 sim-i-setup.sh ${ENTRYPOINTD}/50-sim-i-setup.sh
USER coder
