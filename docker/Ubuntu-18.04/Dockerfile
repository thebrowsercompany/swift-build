ARG toolchain='https://compnerd.visualstudio.com/3133d6ab-80a8-4996-ac4f-03df25cd3224/_apis/build/builds/14589/artifacts?artifactName=linux-toolchain-amd64.deb&api-version=5.1&%24format=zip'
ARG sdk='https://compnerd.visualstudio.com/3133d6ab-80a8-4996-ac4f-03df25cd3224/_apis/build/builds/14590/artifacts?artifactName=linux-swift-sdk.deb&api-version=5.1&%24format=zip'

FROM ubuntu:18.04 as ubuntu

LABEL maintainer="compnerd@compnerd.org"

RUN apt-get -yq update                                                      \
 && apt-get -yq upgrade                                                     \
 && apt-get -yq install --no-install-recommends ca-certificates curl unzip  \
 && curl -L ${toolchain} -o linux-toolchain-amd64.zip                       \
 && curl -L ${sdk} -o linux-sdk.zip                                         \
 && unzip linux-toolchain-amd64.zip                                         \
 && unzip linux-sdk.zip                                                     \
 && dpkg -i linux-toolchain-amd64.deb/toolchain.deb                         \
 && dpkg -i linux-swift-sdk.deb/sdk.deb                                     \
 && rm -rf linux-toolchain-amd64*                                           \
 && rm -rf linux-sdk*                                                       \
 && apt-get -yq purge ca-certificates curl unzip                            \
 && apt autoremove -yq                                                      \
 && apt-get clean                                                           \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*

WORKDIR /SourceCache
VOLUME ["/SourceCache"]
