# RengaPorts

Build recipes and the package repository for software built for **Renga**,
the Haiku-based operating system developed at
[Techniix/haiku](https://github.com/Techniix/haiku) (branch `ce/main`).

## What belongs here

| Repository | Holds | Runs on |
| --- | --- | --- |
| [HaikuPorts](https://github.com/haikuports/haikuports) | The official ports for Haiku | Haiku and Renga |
| [Techniix/haiku-packages](https://github.com/Techniix/haiku-packages) | Techniix ports built for stock Haiku | Haiku (and Renga) |
| **RengaPorts** (this repository) | Ports built for Renga: programs that use Renga's own APIs (for example `epoll`, `inotify`, `signalfd`, `memfd` and the other interfaces listed in the Renga porting guide), and Renga builds of programs that also exist for Haiku | Renga only |

A program can have a Haiku version (in its project's own recipe and
`haiku-packages`) and a Renga version (here) at the same time. The two are
kept apart so that neither build is mixed into the other's repository.

## Layout

```
<category>/<port>/<port>-<version>.recipe   HaikuPorter recipes, same layout as HaikuPorts
<category>/<port>/patches/                  patches, as in HaikuPorts
repository/x86_64/repo.info                 description of the published package repository
tools/update-repo.sh                        adds built packages and publishes the repository
```

Recipes use the HaikuPorts recipe format and conventions
([HaikuPorter guidelines](https://github.com/haikuports/haikuports/wiki)).
Dependencies that are not Renga-specific come from HaikuPorts.

### Renga-only packages

Every package built here declares that it needs Renga:

```
REQUIRES="
	haiku
	renga >= 1
	...
	"
```

Renga's system package provides `renga`, so `pkgman` and HaikuDepot refuse
to install these packages on stock Haiku instead of failing at run time.

## Using the repository

Renga images come with this repository configured. To add it by hand:

```sh
pkgman add-repo https://techniix.github.io/RengaPorts/x86_64/current
```

Renga images give it precedence over HaikuPorts (priority 1 against
HaikuPorts' 2; the lower number wins), so where a program exists in both,
the Renga build is installed.

## Publishing packages

Packages are built with HaikuPorter on Renga. `tools/update-repo.sh` then
adds them to the repository:

```sh
tools/update-repo.sh path/to/<package>-<version>-<revision>-x86_64.hpkg ...
```

It replaces older versions of the same package, rebuilds the repository
index with `package_repo`, and publishes the result as a single commit on
the `packages` branch, which GitHub Pages serves. The `main` branch, with
the recipes, keeps its normal history.

## Licences

Each port keeps the licence of the software it packages; recipes and
patches state theirs. The recipes and tools in this repository are under
the MIT licence (see `LICENSE`).
