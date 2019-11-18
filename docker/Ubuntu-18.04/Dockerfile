# Copyright 2019 Saleem Abdulrasool <compnerd@compnerd.org>

FROM ubuntu:18.04 as ubuntu

LABEL maintainer="compnerd@compnerd.org"

ARG TOOLCHAIN=https://compnerd.visualstudio.com/3133d6ab-80a8-4996-ac4f-03df25cd3224/_apis/build/builds/14681/artifacts?artifactName=linux-toolchain-amd64.deb&api-version=5.1&%24format=zip
ARG SDK=https://compnerd.visualstudio.com/3133d6ab-80a8-4996-ac4f-03df25cd3224/_apis/build/builds/14682/artifacts?artifactName=linux-swift-sdk.deb&api-version=5.1&%24format=zip
ARG CODE_SERVER=https://github.com/cdr/code-server/releases/download/2.1692-vsc1.39.2/code-server2.1692-vsc1.39.2-linux-x86_64.tar.gz

ENV LANG=C.UTF-8 SHELL=/bin/bash

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -yq update                                                                      \
 && apt-get -yq upgrade                                                                     \
 && apt-get -yq install --no-install-recommends ca-certificates curl unzip                  \
 && apt-get -yq install --no-install-recommends dumb-init libatomic1 libedit2 libpython2.7  \
 && curl -L ${TOOLCHAIN} -o linux-toolchain-amd64.zip                                       \
 && curl -L ${SDK} -o linux-swift-sdk.zip                                                   \
 && curl -OL ${CODE_SERVER}                                                                 \
 && unzip linux-toolchain-amd64.zip                                                         \
 && unzip linux-swift-sdk.zip                                                               \
 && tar zxf code-server*.tar.gz                                                             \
 && dpkg -i linux-toolchain-amd64.deb/toolchain.deb                                         \
 && dpkg -i linux-swift-sdk.deb/sdk.deb                                                     \
 && cp code-server*/code-server /usr/local/bin/code-server                                  \
 && rm -rf linux-toolchain-amd64*                                                           \
 && rm -rf linux-swift-sdk*                                                                 \
 && rm -rf code-server*                                                                     \
 && apt-get -yq purge ca-certificates curl unzip                                            \
 && apt autoremove -yq                                                                      \
 && apt-get clean                                                                           \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*                    \
 && mkdir -p /SourceCache "/Library/Application Support/com.coder.code-server"

WORKDIR /SourceCache
VOLUME ["/SourceCache"]

EXPOSE 8080
ENTRYPOINT ["dumb-init", "--", "code-server", "--host", "0.0.0.0", "--auth", "none", "--user-data-dir", "/Library/Application Support/com.coder.code-server", "/SourceCache"]
