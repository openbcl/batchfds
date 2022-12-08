# fds base image
FROM openbcl/fds:6.7.9

# copy BatchFDS
COPY src/BatchFDS.sh /usr/local/bin/

# install dos2unix
RUN apt-get update && apt-get install -y dos2unix

# convert CRLF to LF
RUN dos2unix -q /usr/local/bin/BatchFDS.sh

ENTRYPOINT ["BatchFDS.sh"]