# Release Process

The swift-build repository needs a new release branch that tracks a corresponding
Swift release branch, every time Swift cuts a new release branch. This branch
in responsible for building the toolchain for that branch only.

This guide details which things need to be updated when
the `swift-build` release branch is created.

## Github swift-toolchain workflow update

The swift-toolchain workflow needs to be updated once a new branch is created.

Firstly, the branch that the `repo` tool uses is inferred from the Swift version given to the 
github action. The repo tool checks
out the Swift repos from the manifest provided in the XML file. These lines
specify the Swift version passed to the Github action:

```cmd
      swift_version:
        description: 'Swift Version'
        default: '0.0.0'
        required: false
        type: string
```

Instead of the the '0.0.0', the default should be changed to the version that's
used by the release branch. For instance, for the 5.10 Swift release the default
should be set to '5.10.0':

```cmd
      swift_version:
        description: 'Swift Version'
        default: '5.10.0'
        required: false
        type: string
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
