# Copyright 2019 Saleem Abdulrasool <compnerd@compnerd.org>

FROM ubuntu:18.04 as ubuntu

LABEL maintainer="compnerd@compnerd.org"

ARG CODE_SERVER=https://github.com/cdr/code-server/releases/download/2.1692-vsc1.39.2/code-server2.1692-vsc1.39.2-linux-x86_64.tar.gz
# TODO(compnerd) why can this not be installed by name? (ms-vscode.cmake-tools)
ARG MS_VSCODE_CMAKE_TOOLS=https://github.com/microsoft/vscode-cmake-tools/releases/download/v1.2.2/cmaketools.vsix

ENV LANG=C.UTF-8 SHELL="/bin/bash"

ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt-get -yq update                                                          \
 && apt-get -yq upgrade                                                         \
 && apt-get -yq install --no-install-recommends                                 \
     ca-certificates curl gnupg software-properties-common                      \
     dumb-init libatomic1 libedit2 libpython2.7                                 \
     git ninja-build                                                            \
     libc6-dev libgcc-8-dev libncurses-dev libstdc++-8-dev                      \
 && ( curl -qL https://apt.kitware.com/keys/kitware-archive-latest.asc |        \
          apt-key add - )                                                       \
 && apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main'        \
 && apt-add-repository 'deb https://dl.bintray.com/compnerd/swift bionic main'  \
 && apt-get -yq update                                                          \
 && apt-get -yq install --no-install-recommends cmake                           \
 && apt-get -yq install --no-install-recommends swift-toolchain swift-icu swift-android-sdk swift-linux-sdk swift-windows-sdk swift-devtools \
 && curl -OL ${CODE_SERVER}                                                     \
 && tar zxf code-server*.tar.gz                                                 \
 && cp code-server*/code-server /bin/code-server                                \
 && curl -OL ${MS_VSCODE_CMAKE_TOOLS}                                           \
 && code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension cmaketools.vsix  \
 && rm -rf code-server*                                                         \
 && rm -rf *.vsix                                                               \
 && apt-get -yq purge --auto-remove                                             \
        ca-certificates curl gnupg software-properties-common                   \
 && apt-get clean                                                               \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*

RUN code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension ms-vscode.cpptools
RUN code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension ms-vscode.vs-keybindings
RUN code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension vscodevim.vim
RUN code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension twxs.cmake
RUN mkdir -p /SourceCache /BinaryCache

RUN adduser --home /Users/Shared --gecos '' --disabled-password swift
USER swift

ENV HOME=/Users/Shared XDG_DATA_HOME="/Users/Shared/Library/Application Support" CMAKE_EXPORT_COMPILE_COMMANDS=YES

ADD --chown=swift:swift ["cmake-tools-kits.json", "/Users/Shared/Library/Application Support/CMakeTools/cmake-tools-kits.json"]
ADD --chown=swift:swift ["settings.json", "/Users/Shared/Library/Application Support/com.coder.code-server/User/settings.json"]
ADD --chown=swift:swift cmake/ /Users/Shared/cmake

VOLUME ["/SourceCache", "/BinaryCache"]

EXPOSE 8080
ENTRYPOINT ["dumb-init", "--", "code-server", "--host", "0.0.0.0", "--auth", "none", "--user-data-dir", "/Users/Shared/Library/Application Support/com.coder.code-server", "--extra-extensions-dir", "/Library/Application Support/com.coder.code-server/extensions", "/SourceCache"]
