# Code Quality

## Incremental Formatting and Linting for Swift Source Code


### Overview
The merits of using a code formatter and linter for any codebase are many. The mark of a high quality code base is standardized coding guidelines with formatting and linting enforced automatically. However, for a lot of codebases the use for a formatted and linter are an after thought; but it is never too late to adopt these tools for any codebase, be it single contributor or many. That is because utilizing code formatter and linting tools will enhance the state of any codebase and boost developer productivity, in addition to gaining consistency, improved readability, and reduced friction during code reviews.

The goal is to automate as much of the formatting and linting rules as possible and **only format and lint source code that has changed**. Therefore, incremental adoption is the best way forward and eases people into the flow where the code is automatically formatted, as much as possible, and where it can't be automatically formatted an appropriate warning or error is raised.

### Required Tooling
[SwiftFormat](https://github.com/nicklockwood/SwiftFormat) and [SwiftLint](https://realm.github.io/SwiftLint/) are the two tool used and required by these scripts. With the primary IDE being Xcode where the scripts included in this repository are used. However, these scripts can be used with any platform and IDE where both, _SwiftFormat_ and _SwiftLint_, are available. Please see the installation of the two tools is out of scope for this document, therefore please see the installation instructions at their respective links above.

> [!IMPORTANT]
> The source code **must** be under `git` source control in order for the scripts to work correctly. Contributions are welcome for supporting other VCS.


| File | Description |
|------|-------------|
| `swiftformat.sh` | When executed it will get the list of changed files and invoke the formatter tool _only_ on those files. |
| `swiftlint.sh` | The script will gather all changed files and will invoke the linting tool _only_ on those files |
| `canonicalize_filename.sh` | This script is a dependency of the previous two scripts | 

### Auto Apply and Auto Fix

The formatting and linting scripts offer auto-correction of all violations that are offered by the underlaying formatting and linting tools.

| Script | Variable | Value | Description and Usage |
|--------|----------|-------|------------------------
| `swiftformat.sh` | `AUTO_APPLY` | `true` (default) | All correctable violations will be automatically corrected. |
| | | `false` | No auto-correction of violation. However, the script will create a `patch` file for all necessary changes and will output the path to this file along with the `git` command to apply the changes manually in the logs (or `stdout` if run from the Terminal). |
| `swiftlint.sh` | `AUTO_FIX` | `true` (default) | All correctable violations will be automatically corrected. |
| | | `false` | No auto-correction of violation. However, the script will create a `patch` file for all necessary changes and will output the path to this file along with the `git` command to apply the changes manually in the logs (or `stdout` if run from the Terminal). |

### Configuration

1. You can copy all of the scripts in this repository anywhere under your project's root directory. I usually put them in a folder called `Scripts`, hence the example paths will use that; so be sure to use the path in your build phase.
2. Make sure the scripts have execution permission set on them.
3. Open your project in Xcode``
4. Click on the root node (should be your project name) in the Project Navigator
    i. In case you have open a workspace or have nested projects, select the project that is the main project
5. In the content editor, select your app's target (the one where the source code needs formatting)
6. Then click on the "Build Phases" tab
7. Click the "+" (plus) button and select "New Run Script Phase"
8. Rename the newly added phase to "Code Formatter" or whatever you like to name it
9. Open the newly added script phase by clicking on the ">" (chevron) that left of the phase name
10. In the shell script editor, add the following: `"${SRCROOT}/Scripts/swiftformat.sh"`
11. Repeat steps 5 to 8 for adding the a new script phase for the linting tool; however, this time in the script editor add the following: `"${SRCROOT}/Scripts/swiftlint.sh"`
12. Move both the formatting and linting phases to the be right before the "Compile Sources" phase; see [Reasoning](#Reasoning) below.
13. In the build settings for the target, please make sure that the scripting sandbox, `ENABLE_USER_SCRIPT_SANDBOXING`, setting is set to `NO`; otherwise Xcode will prevent these scripts from running.

### Reasoning

The reasoning behind moving both the formatting and linting tasks to be run prior to compiling the source code is to raise formatting and linting issues as early as possible, reducing the wait time for the issues that the developer will need to address. The tool run really fast thus not having any adverse affects on the project build times.

Having the formatter added to the build phase also allows us to run the formatting for the code at *build time*. The key takeaway here is that the most of the formatting changes can be applied automatically and *only for the files that were changed* and **not the whole code base**. This also applies to the linter, that too will only run on files that were changes and not the entire codebase.

Lastly, the tools will be configured to fix anything that can be automatically fixed, thus reducing the burden on the developers to manually fixing each issue. However, please note that not all issues can be automatically fixed by either the formatter or the linter; therefore, the issues that cannot be fixed automatically, the will need to be addressed manually.

### Caveats

> [!IMPORTANT]
> Fight the urge to turn everything into a warning. These pile up quick and will reduce the effectiveness of the formatting and linting tools and will adversely affect the codebase.

> [!CAUTION]
> Once the code is automatically formatted using the scripts via build phase, the undo buffer for the source editor in Xcode is cleared. This means that there won't be any undo history once the changes are applied. This seems to be an issue with recent Xcode versions; at least I don't recall encountering this prior to Xcode 14...¯\_(ツ)_/¯ 
>
> If you would like to keep the undo history, see the [Auto Apply and Auto Fix](#auto-apply-and-auto-fix) section for turning off auto-correction.
