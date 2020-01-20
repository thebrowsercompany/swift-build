# Copyright 2019 Saleem Abdulrasool <compnerd@compnerd.org>

FROM ubuntu:18.04 as ubuntu

LABEL maintainer="compnerd@compnerd.org"

ARG CODE_SERVER=https://github.com/cdr/code-server/releases/download/2.1698/code-server2.1698-vsc1.41.1-linux-x86_64.tar.gz

ENV LANG=C.UTF-8 SHELL="/bin/bash"

ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt-get -yq update                                                          \
 && apt-get -yq upgrade                                                         \
 && apt-get -yq install --no-install-recommends                                 \
     curl gnupg                                                                 \
     ca-certificates dumb-init libatomic1 libedit2 libpython2.7                 \
     git ninja-build                                                            \
     libc6-dev libgcc-8-dev libncurses-dev libstdc++-8-dev                      \
 && curl -sL https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add -        \
 && echo 'deb https://apt.kitware.com/ubuntu/ bionic main' >> /etc/apt/sources.list         \
 && echo 'deb [trusted=yes] https://swift.apt.compnerd.org/apt/ /' >> /etc/apt/sources.list \
 && apt-get -yq update                                                          \
 && apt-get -yq install --no-install-recommends cmake                           \
 && apt-get -yq install --no-install-recommends swift-toolchain swift-icu swift-android-sdk swift-linux-sdk swift-windows-sdk swift-devtools \
 && curl -sOL ${CODE_SERVER}                                                    \
 && tar zxf code-server*.tar.gz                                                 \
 && cp code-server*/code-server /bin/code-server                                \
 && rm -rf code-server*                                                         \
 && apt-get -yq purge --auto-remove curl gnupg                                  \
 && apt-get clean                                                               \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/archive/* /var/lib/apt/lists/*

RUN code-server --extensions-dir "/Library/Application Support/com.coder.code-server/extensions" --install-extension ms-vscode.cmake-tools
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
