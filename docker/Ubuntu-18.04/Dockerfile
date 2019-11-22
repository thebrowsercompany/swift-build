# Copyright 2019 Saleem Abdulrasool <compnerd@compnerd.org>

FROM ubuntu:18.04 as ubuntu

LABEL maintainer="compnerd@compnerd.org"

ARG TOOLCHAIN=https://compnerd.visualstudio.com/3133d6ab-80a8-4996-ac4f-03df25cd3224/_apis/build/builds/14839/artifacts?artifactName=linux-toolchain-amd64.deb&api-version=5.1&%24format=zip
ARG SDK=https://compnerd.visualstudio.com/3133d6ab-80a8-4996-ac4f-03df25cd3224/_apis/build/builds/14840/artifacts?artifactName=linux-swift-sdk.deb&api-version=5.1&%24format=zip
ARG CODE_SERVER=https://github.com/cdr/code-server/releases/download/2.1692-vsc1.39.2/code-server2.1692-vsc1.39.2-linux-x86_64.tar.gz
# TODO(compnerd) why can this not be installed by name? (ms-vscode.cmake-tools)
ARG MS_VSCODE_CMAKE_TOOLS=https://github.com/microsoft/vscode-cmake-tools/releases/download/v1.2.2/cmaketools.vsix

ENV LANG=C.UTF-8 SHELL=/bin/bash

ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt-get -yq update                                                          \
 && apt-get -yq upgrade                                                         \
 && apt-get -yq install --no-install-recommends                                 \
     ca-certificates curl gnupg software-properties-common unzip                \
     dumb-init libatomic1 libedit2 libncurses6 libpython2.7                     \
     git ninja-build                                                            \
     libc6-dev libgcc-8-dev libncurses-dev libstdc++-8-dev                      \
 && ( curl -qL https://apt.kitware.com/keys/kitware-archive-latest.asc |        \
          apt-key add - )                                                       \
 && apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main'        \
 && apt-get -yq update                                                          \
 && apt-get -yq install --no-install-recommends cmake                           \
 && curl -L ${TOOLCHAIN} -o linux-toolchain-amd64.zip                           \
 && curl -L ${SDK} -o linux-swift-sdk.zip                                       \
 && curl -OL ${CODE_SERVER}                                                     \
 && unzip linux-toolchain-amd64.zip                                             \
 && unzip linux-swift-sdk.zip                                                   \
 && tar zxf code-server*.tar.gz                                                 \
 && dpkg -i linux-toolchain-amd64.deb/toolchain.deb                             \
 && dpkg -i linux-swift-sdk.deb/sdk.deb                                         \
 && cp code-server*/code-server /bin/code-server                                \
 && curl -OL ${MS_VSCODE_CMAKE_TOOLS}                                           \
 && code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension cmaketools.vsix    \
 && code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension twxs.cmake         \
 && code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension xaver.clang-format \
 && code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension vscodevim.vim      \
 && rm -rf linux-toolchain-amd64*                                               \
 && rm -rf linux-swift-sdk*                                                     \
 && rm -rf code-server*                                                         \
 && rm -rf *.vsix                                                               \
 && apt-get -yq purge --auto-remove                                             \
        ca-certificates curl gnupg software-properties-common unzip             \
 && apt-get clean                                                               \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*        \
 && mkdir -p /SourceCache /BinaryCache                                          \
 && mkdir -p /root/.local/share/CMakeTools                                      \
 && mkdir -p "/Users/Shared/Library/Application Support/com.coder.code-server"

ADD cmake-tools-kits.json /root/.local/share/CMakeTools/cmake-tools-kits.json
ADD ["settings.json", "/Users/Shared/Library/Application Support/com.coder.code-server/User/settings.json"]
ADD cmake/ /Users/Shared/cmake

VOLUME ["/SourceCache", "/BinaryCache"]

EXPOSE 8080
ENTRYPOINT ["dumb-init", "--", "code-server", "--host", "0.0.0.0", "--auth", "none", "--user-data-dir", "/Users/Shared/Library/Application Support/com.coder.code-server", "--extra-extensions-dir", "/Library/Application Support/com.coder.code-server/extensions"]
