#!/bin/sh
mkdir -p ${HOME}/Source
mkdir -p ${HOME}/Library/Developer/org.compnerd.dt/DerivedData
mkdir -p ${HOME}/.config/Code
sudo docker run --detach --publish 0.0.0.0:8080:8080 --cap-add SYS_PTRACE --security-opt seccomp=unconfined --volume ${HOME}/Source:/SourceCache --volume ${HOME}/Library/Developer/org.compnerd.dt/DerivedData:/BinaryCache --volume "${HOME}/.config/Code:/Users/Shared/Library/Application Support/com.coder.code-server" compnerd/swift
