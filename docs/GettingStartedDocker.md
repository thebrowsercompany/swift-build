# **//swift/build**

## Table of Contents

* [Getting Started with Docker](#getting-started-with-docker)
* [Minimal Hello World (CMake)](#minimal-hello-world--cmake-)

## Getting Started with Docker

Getting started is as simple as running a command from your shell:

```Shell
$ docker run --rm --publish 127.0.0.1:8080:8080 --volume $HOME/projects/myproject:/SourceCache/myproject --volume $HOME/projects/bin/myproject:/BinaryCache/myproject compnerd/swift:latest
```

* The docker image doesn't require persistent state, so we use `--rm` to automatically clean up and remove the container when it exits.
* Visual Studio Code is exposed over a web interface on port 8080. We publish this port via `--publish 127.0.0.1:8080:8080` <sup>[1](#footnote-1)</sup>.
* `--volume $HOME/projects/myproject:/SourceCache/myproject` and `--volume $HOME/projects/bin/myproject:/BinaryCache/myproject` mount your source tree for "myproject" into the docker image as a subdirectory of `/SourceCache` and the directory for compiled output into it as `/BinaryCache`.
* `compnerd/swift` references the latest tag on [Docker Hub](https://hub.docker.com/r/compnerd/swift).

<sup><a name="footnote-1">1</a></sup> If you'd like to access this from anywhere other than localhost, you can replace this with `--publish 0.0.0.0:8080:8080`, but no authentication or HTTPS are configured, so doing this with no additional configuration will be insecure.

## Minimal Hello World (CMake)

First, clone the examples repository:

```Shell
$ git clone https://github.com/compnerd/swift-build-examples.git
```

Next, make a directory for the binary output (remember to substitute your own path!):

```Shell
$ mkdir -p $HOME/bin/HelloMinimal-CMake
```

Next start up the build environment:

```Shell
$ docker run --rm --publish 127.0.0.1:8080:8080 --volume /path/to/swift-build-examples/HelloMinimal-CMake:/SourceCache/HelloMinimal-CMake --volume $HOME/bin/HelloMinimal-CMake:/BinaryCache/HelloMinimal-CMake compnerd/swift:latest
```

Navigate to localhost in your browser: [http://127.0.0.1:8080](http://127.0.0.1:8080). Or, if you want to open a workspace directly, you can provide a path: [http://localhost:8080/?folder=/SourceCache/HelloMinimal-CMake](http://localhost:8080/?folder=/SourceCache/HelloMinimal-CMake)

Visual Studio Code will prompt you to configure your project with CMake - choose "Yes".

!["Configure this Project" dialog](resources/getting-started-docker/configure-this-project.png)

You will be offered a selection of CMake Kits. This dictates the target system that this session will build. For this example, select "Linux x86_64".

![CMake Kit selection](resources/getting-started-docker/select-kit.png)

You may be asked whether Visual Studio Code should always configure CMake projects upon opening. You can choose either "Yes" or "For this Workspace"; all this does is add a setting to `.vscode/settings.json`. Because we run a fresh image on each run of the docker container, You will need to click "Yes" on each new run of the container, or "For this Workspace" to do so automatically your current workspace. Note that you will still have to select your desired CMake Kit on each startup.

!["Always Configure" dialog](resources/getting-started-docker/always-configure.png)

If you did not open Visual Studio Code with the "folder" URL parameter, click File -> Open... to do so and choose `/SourceCache/HelloMinimal-CMake`. By default, `/SourceCache` will be opened, but this will not necessarily set up a working CMake project in a subdirectory. Hit "Enter".

!["Open" dialog](resources/getting-started-docker/open.png)
!["Open" dialog 2](resources/getting-started-docker/open2.png)

Once you do so, you should see `CMakeLists.txt`, `hello.swift`, `hikit.swift`, and, if you chose "For this Workspace", a `.vscode` directory.

![File listing](resources/getting-started-docker/files.png)

At the bottom of the screen, your toolbar will have CMake information. Ensure that the "Linux x86_64" kit is selected, and click the "Build:" button (in the future, if you want to rebuild only specific CMake targets, you can click "\[all\]" and select them specifically).

![CMake toolbar](resources/getting-started-docker/toolbar.png)

Your program is now compiled; now let's test it out. Open a shell with "Ctrl-`" (Ctrl-Backtick), and run it with:

```Shell
$ /BinaryCache/HelloMinimal-CMake/Debug/hello
```

![Hello World program](resources/getting-started-docker/hello-world.png)

Congratulations! You've built and run your first Swift program with swift-build-configuration!

