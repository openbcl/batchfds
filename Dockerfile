# FDS version (default: latest), e.g. 6.9.0
ARG FDS_VERSION=latest

# FDS base image
FROM ghcr.io/openbcl/fds:${FDS_VERSION}

# copy BatchFDS
COPY src/BatchFDS.sh /usr/local/bin/

# make BatchFDS executable
RUN chmod +x /usr/local/bin/BatchFDS.sh

ENTRYPOINT ["BatchFDS.sh"]