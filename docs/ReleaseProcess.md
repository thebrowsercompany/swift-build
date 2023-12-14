# Release Process

The swift-build repository needs a new release branch that tracks a corresponding
Swift release branch, every time Swift cuts a new release branch. This branch
in responsible for building the toolchain for that branch only.

This guide details which things need to be updated when
the `swift-build` release branch is created.

## Github swift-toolchain workflow update

The swift-toolchain workflow needs to be updated once a new branch is created.

Firstly, the branch that the `repo` tool uses should be updated. The repo tool checks
out the Swift repos from the manifest provided in the XML file. This line
in the workflow YAML file sets it up:

```cmd
repo init --quiet --groups default --depth 1 -u https://github.com/compnerd/swift-build -b main
```

The new branch should instead point to itself instead of `main`, e.g. for `release/5.10`:

```cmd
repo init --quiet --groups default --depth 1 -u https://github.com/compnerd/swift-build -b release/5.10
```

Then, the `repo` tool manifest should be updated. It's specified in the `default.xml` file.
Branches should follow the release conventions instead of main. The primary branch for most repos 
is specified in the `default` XML item:

```xml
 <default revision="main" sync-c="true" sync-tags="false" />
 ```

This should be changed to appropriate release default, e.g. `release/5.10`.
Certain other repos need a different default. For example, llvm-project uses
the `swift/release/5.10` convention instead, and thus it has to be specified
manually in the repo reference item, so for the 5.10 release it should look like:

```xml
<project remote="github" name="apple/llvm-project" path="llvm-project" revision="swift/release/5.10" />
```

You can look at the `default.xml` file in the prior release branch to see which repos need to follow
custom conventions instead of using the default release branch name.
