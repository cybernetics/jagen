# jagen

A straightforward build system generator.

Aimed for cases when OpenEmbedded is too magical and hard to configure for
obscure vendor SDK of choice. Intended to ease the pain of development of
multiple interdependent software packages with non standard toolchains,
cross-compilation and complex build dependencies. Based on ideas from Gentoo
Portage, GNU Guix and Nix package managers.

## Requirements

POSIX compatible shell, Lua 5.1, [Ninja](https://ninja-build.org/)

## Usage

### Build

Usage: jagen build [OPTION...] [TARGET...]

  Builds or rebuilds the specified targets.

OPTIONS

  -h, --help          print this help message
  -n, --dry-run       print expanded value of TARGET... arguments and exit
  -p, --progress      show TARGET's build progress
  -P, --all-progress  show all build output
  -f, --from          rebuild starting from the specified targets
  -o, --only          build only matching targets

  Use command 'jagen help targets' for information about targets.

SYNOPSIS

  If no targets were specified the command builds everything not already built;
  otherwise it expands TARGET... arguments and builds the resulting targets if
  they are out of date. The '--from' option causes the specified targets to be
  rebuilt unconditionally following by their dependencies until everything is
  up to date, use '--only' option to skip rebuilding dependencies.

  Short options can be combined into a single argument, for example:

    jagen build -fop libuv

  will rebuild libuv package from scratch, but nothing else, showing progress
  on console. This will make targets depending on libuv out of date, so the
  next 'jagen build' invocation will rebuild them too.

  For development and testing it can be more convenient to select specific
  targets, like:

    jagen build -fp libuv:compile:target

  This will recompile libuv for target configuration if needed, then reinstall
  it to rootfs or firmware image according to the rules currently in effect.

### Clean

Usage: jagen clean

  Deletes all generated files and directories inside the current build root.

SYNOPSIS

  The following directories are recursively deleted:

    jagen_build_dir
    jagen_include_dir
    jagen_log_dir
    jagen_host_dir
    jagen_target_dir

  Actual paths depend on configuration. After the deletion regenerates the
  build system using the 'jagen refresh' command.

### Refresh

Usage: jagen refresh

  Regenerates the build system from rules according to configuration.

### Targets

  Targets are specified as '<name>:<stage>:<config>'. Available package stages
  are filtered with the given expression. Omitted component means 'all'.  For
  example:

  utils              - select all stages of the utils package
  utils:install      - select all utils install stages
  utils::host        - select all host utils stages
  utils:compile:host - select only host utils compile stage
  :build:host        - select host build stages of all packages

  When a target is succesfully built the stamp file is created in the build
  directory with the name: <name>__<stage>__<config>. This file is used to
  determine if the target is up to date. Deleting it will cause the
  corresponding target to be rebuilt unconditionally next time the build system
  runs.

### Sources

Usage: jagen src <command> [PACKAGES...]

  Manage SCM package sources.

SYNOPSIS

  The optional PACKAGES argument should be the list of SCM packages defined in
  the current environment. If none are specified, all are assumed.

COMMANDS

  dirty   Check if packages source directories have any changes
  status  Show packages location, head commit and dirty status
  clean   Clean up packages source directories
  update  Update the sources to the latest upstream version
  clone   Clone the specified packages
  delete  Delete packages source directories

  The 'dirty' command exits with 0 (true) status if any of the specified
  packages source directories have changes. It exits with 1 (false) status if
  all sources are clean. Intended for usage by shell scripts.

  The 'status' command prints SCM packages status in human readable form.

  The 'clean' command resets modifications to the HEAD state and deletes
  all extra files in packages source directories.

  The 'update' command fetches the latest sources from upstream and tries to
  merge them with the current source directories.

  The 'clone' command clones the specified packages.

  The 'delete' command deletes packages source directories.
