# Saigo Native Client Compiler Collection

[![GitHub tag](https://img.shields.io/github/release/DaemonEngine/saigo-release-scripts.svg)](https://github.com/DaemonEngine/saigo-release-scripts/releases/latest)

[![IRC](https://img.shields.io/badge/irc-%23unvanquished--dev-9cf.svg)](https://unvanquished.net/chat/)
[![Matrix](https://img.shields.io/badge/matrix-Unvanquished-9cf)](https://matrix.to/#/!WnuetRiQZJNBTKwMrF:matrix.org?via=matrix.org)
[![Discord](https://img.shields.io/badge/discord-Unvanquished-9cf)](https://discord.gg/usuDT9Pyna)

This project makes possible to rebuild the Native Client compiler collection for usage with the [Dæmon game engine](https://github.com/DaemonEngine/Daemon).
The Dæmon engine is the open-source game engine powering the [Unvanquished game](https://unvanquished.net).

Saigo is a modern toolchain for compiling Native Client applications.

Google publicly announced [in May of 2017](https://www.tomshardware.com/news/chrome-deprecates-pnacl-embraces-webassembly%2C34583.html) the (then-)upcoming deprecation and abandonment of Native Client technologies in favor of WebAssembly, and announced the actual deprecation [in 2020](https://developer.chrome.com/deprecated).
But Google also [supported](https://developer.chrome.com/docs/native-client) Native Client-powered ChromeOS 138 until ChromeOS 129 [in July of 2025](https://support.google.com/chrome/a/answer/10314655?&#139) and as such continued developpement of some Native Client technologies.
This extra development materialized in the maintenance of a toolchain named Saigo, frequently rebased on the latest LLVM upstream at the time. Saigo received commits from Google until January of 2025 and the last rebase was over Clang 21.

Google never compiled Saigo for something else than Linux amd64, and their build process relied on a very complex collection of repositories involving prebuilt binaries. This project not only makes possible to rebuild Saigo for your preferred system and architecture, but does it without running any shady precompiled executable provided by Google.

This repository doesn't contain any Saigo code, it provides scripts to build Saigo using Google upstream repositories:

- [chromium.googlesource.com/native_client/nacl-llvm-project-v10](https://chromium.googlesource.com/native_client/nacl-llvm-project-v10) (Saigo clang)
- [chromium.googlesource.com/native_client/nacl-binutils](https://chromium.googlesource.com/native_client/nacl-binutils) (Saigo binutils)

We provide patches (stored in this repository) that CMake automatically applies on upstream repositories before building the software. Those patches keep the tools buildables and makes them more cross-platform (buildable on more systems and architectures).

The related project to rebuild without Google's complex collection of repositories and without shady Google's precompiled binaries and with our own fixes the Native Client loader can be found there:

- [github.com/DaemonEngine/native_client](https://github.com/DaemonEngine/native_client)

In Japanese, _Saigo_ (さいご / 最後) means “_the last_”, “_the end_”, “_the final_” or “_the conclusion_”. This refers to the end of an era, the final stage of an event, or the last item in a sequence…

Nothing about Native Client should be expected from Google anymore.


## Status

Component|Status
-|-
Saigo native clang|✅️ Rebuilt from scratch
Saigo native binutils|✅️ Rebuilt from scratch
Saigo nexe libc|☑️ Repackaged
Saigo nexe libc++|☑️ Repackaged

It is now possible to rebuild the compiler binaries (the NaCl Saigo Clang and related binutils), and to do it for more platforms than initially supported by Google.

The compiler binaries have been successfully built for:

Architecture|Linux|Windows|macOS|FreeBSD
-|-|-|-|-
amd64|✅️|✅️|✅️|✅️
i686|✅️|✅️|
arm64|✅️||✅️
armhf|✅️
ppc64el|✅️
riscv4|✅️
loong64|✅️

This is only about running the compilers natively to compile NaCl code, the NaCl loader (for running NaCl code) has stricter limitations.

The Windows build is meant to be cross-compiled on Linux using MinGW.

For now, the libc and libc++ libraries are copied from pre-compiled libraries provided by Google.

Those libraries only contribute to binaries that run inside in the untrested environment of the Native Client virtual machine, meaning no pre-compiled code runs in the trusted environement outside of the Native Client virtual machine.

This project then already achieved the ability for someone to be able to recompile all the trusted code and then never have to run any precompiled trusted code.

The toolchain being buildable for some platforms only means it's possible to run the toolchain on those platforms to produce Native Client executables (nexe), it doesn't mean those Native Client executable can run on those platform. Running Native Client executables on new platforms would require new code in both the toolchain and the loader and this is not planned.

On platforms that can run the loader under some compatibility mode (like running 32-bit loader on 64-bit environment, or Linux running [box64](https://box86.org), or macOS running amd64 loader through Rosetta 2 on arm64, or FreeBSD running the Linux loader on Linuxulator, it means it makes possible to have a fully native toolchain to produce NaCl binaries (once the required libc and libc++ are installed too).


## Workspace requirements

Those build scripts and CMake configuration are only tested on Unix-like environment, the bash shell and standard coreutils are required.


## Systems

The suported operating systems to build the Saigo toolchain on are Linux, FreeBSD and macOS. Building for Windows is done on Linux through cross-compilation.

Here are the systems you need to build Saigo for specific systems:

Target system|Build system|Compiler
-|-|-
Linux|Linux|GCC
Windows|Linux|MinGW
FreeBSD|FreeBSD|Clang
macOS|macOS|AppleClang


### Tools

Those prerequisites are cumulatives

CMake script:

- `cmake`
- `coreutils` (GNU or BSD)
- `make` (GNU or obsolete Apple GNU)
- `rsync`
- `git`
- A C/C++ compiler collection for the target, the following ones are supported:
  * GCC
  * MinGW
  * Clang
  * AppleClang

Release build script:

- `sed` (GNU or BSD)
- `awk` (GNU or BSD)
- `bash` (GNU or obsolete Apple GNU)

Release packaging script

- `tar` (GNU or BSD)
- `xz`
- `jdupes` or `rdfind`  
   Optional, but recommended to deduplicate tarball content.

Recommended:

- `ccache`  
  Can save recompilation time if when you want to restart the build.
- `ninja`
  May be more efficient than Make, will be used for building LLVM if present.

Even when providing CMake and Ninja, Make will be used for building binutils as binutils build uses autotools and require Make.

CMake will do all the required autotools and make calls automatically.

CMake will also clone the clang and binutils repositories using git and automatically apply the patches.

CMake will also clean-up at the end of the build process the useless stuff built with LLVM that we could not disable.


## Build instructions

### CMake simple build

```
mkdir build && cd build
cmake ..
make -j8
```

A compiler toolchain can then be found in `build/prefix`.

The binutils build relies on autotools and GNU Make, so `gmake` has to be used instead of `make` on BSD systems.

Replace the `8` job count with the amount of cores your computer provides. Rebuilding Clang requires a powerful computer, as compilation is large and slow.

Building LLVM may require 8GB per link task, especially when building it with LTO enabled, so you may prefer to use `<RAM available in GB>/8` as job count.

CMake will replace many known duplicates with symbolinc links.

One can clean the build (including the deletion of the `prefix/` directory) with:

```
make distclean
```

This runs the standard `make clean` action to clean-up build temporary files and reset the build progression, and deletes the `prefix` directory where things have been installed.

Note: Cleaning does not work on FreeBSD because of a bug in autotools.


### Release multi build

Using the `tools/release/build` wrapper only clones repositories once and then saves a lot of time and file space.

It is highly recommended to share the repository over the network accross all the build machine to let the build tasks reuse things as much as possible.

On Linux:

```
tools/release/build linux-amd64 linux-i686 linux-arm64 linux-armhf linux-ppc64el linux-riscv64 linux-loong64 windows-amd64 windows-i686
```

On macOS:

```
tools/release/build macos-amd64 macos-arm64
```

On FreeBSD:

```
tools/release/build freebsd-amd64
```

The configuration for the targets is stored in the `tools/release/conf` directory.

The build directory will be `build/<target>` and the built files will be `build/<target>/prefix`.

For building targets using LTO, one can do:

```
USE_LTO=ON tools/release/build <targets>
```

Beware that building using  LTO is much slower and can require crazy amount of RAM. To prevent the kernel to trigger the OOM killer and to preserve your precious uptime, the `build` script selects the job count accordingly to both CPU core availables and memory available.

The `build` task makes heavy usage of symbolic links to deduplicates file (see above).


### Release multi packaging

Packaging requires the Release multi build script to be used first.

```
tools/release/package freebsd-amd64 linux-amd64 linux-arm64 linux-armhf linux-i686 linux-loong64 linux-ppc64el linux-riscv64 macos-amd64 macos-arm64 windows-amd64 windows-i686
```

The packaged archives will be found in the `build/packages` directory, and the archives will be named `saigocc-<target>_version-<commit date>.tar.xz`.

The `package` task will use `jdupes` or `rdfind` (if present) to deduplicate files even more using hard links before storing them in the tarball.

All symbolink links are turned into hardlinks in the Windows tarballs to both provide an efficient storage and make sure files are extracted as real files and not as broken links on Windows.


### Release multi cleaning

This runs the custom `make distclean` action (see above).

```
tools/release/package linux-amd64 linux-arm64 linux-armhf linux-i686 linux-loong64 linux-ppc64el linux-riscv64 macos-amd64 macos-arm64 windows-amd64 windows-i686
```

Note: Cleaning does not work on FreeBSD because of a bug in autotools.

## History

History of NaCl toolchains, from older to newer (only the latest version of them being mentionned):

- PNaCl GCC (GCC 4.4.3)
- PNaCl Clang (LLVM 3.6)
- Saigo Clang (LLVM 21)

The Saigo toolchain compiler is based on Clang and had been frequently rebased over the latest LLVM, bringing the latest Clang and latest C++ standards to NaCl at the time. Saigo clang has not been updated since January of 2025. We provide a patch to support the GCC LTO Auto option.

The Saigo toolchain also requires a special branch of GNU binutils which hasn't been updated since November of 2014. We provide patches to keep it buildable, make it buildable for more architectures and for more systems like Windows when building with MinGW.

The lastest version of Saigo is based on Clang 21 and as such we can expect C23 support and likely C2y partial draft support, C++23 support and likely C++2c partial draft support.

The libc++ is the one from the same LLVM Saigo is based on, and should be easy to build, unfortunately building some parts of the libc still requires the old NaCl GCC, which is now very old and very hard to build, and Google themselves had gaven up and did not rebuilt it in their scripts.

Out of convenience, the libc++ and libc is currently packaged from prebuilt packages by Google. The libc and the libc++ are linked to binaries running in the Native Client virtual machine and as such, never runs outside of the sandbox.

Everything that runs on the trusted machine (your machine) is rebuilt from scratch and no Google prebuilt binaries will be running on your computer when compiling the Saigo toolchain and when compiling NaCl code with the Saigo toolchain.


## Purpose

Purpose of this project is to provide a way to build native binaries for the toolchain running on developer's computer without:

- using Google-provided binaries to build NaCl code, that means clang and binutils are rebuilt from scratch;
- using Google-provided binaries to rebuild the toolchain itself,  that means means no Google binaries are used to build clang and binutils themselves.

This also allows to run the toolchain on systems not supported by Google. Google only built Saigo for `linux-amd64`, and Google only built PNaCl-clang for `linux-amd64`, `windows-amd64`, `windows-i686` and `macos-am64`.

While the Saigo toolchain can only build `nexe` applications for `amd64`, `i686` and `armhf`, and while there is no Native Client loaders for other architectures and other systems than Linux, Windows and macOS, those `nexe` applications and loaders can run on architecture and system variants using compatibility layers. Those build scripts make possible to run a native Saigo toolchain where the NaCl loader can run through known compatibility layers.

System and Architecture|NaCl loader|Saigo toolchain
-|-|-
Linux amd64|✅️ native|✅️ native
Linux i686|✅️ native|✅️ native
Linux arm64|☑️ compatible (armhf multiarch, box64)|✅️ native
Linux armhf|✅ native|✅️ native
Linux ppc64el|☑️ compatible (box64)|✅️ native
Linux riscv64|☑️ compatible (box64)|✅️ native
Linux loong64|☑️ compatible (box64, untested)|✅️ native
FreeBSD amd64|☑️ compatible (Linuxulator)|✅️ native
macOS amd64|✅️ native|✅️ native
macOS arm64|☑️ compatible (Rosetta 2)|✅️ native
Windows amd64|✅️ native|✅️ native
Windows i686|✅️ native|✅️ native

For the nexe libc and libc++, this project repackages the Google pre-compiled libraries in order to reach a minimimum viable product state. This precompiled code is meant to be executed within the Native Client sandbox and then doesn't require the same level of trust.

Contributions making possible to fully rebuild the libc without any Google-provided binaries is welcome, but doesn't receive the same priority as providing a fully-rebuildable NaCl compiler toolchain.

Rebuilding the NaCl loader is possible thanks to this other project:

- [github.com/DaemonEngine/native_client](https://github.com/DaemonEngine/native_client)


## Supported nexe target platforms

Here are the supported NaCl targets:

- `amd64`
- `i686`
- `armhf`

Saigo itself can be built for `mipsel`, and the NaCl loader can be built for `mipsel`, but Google doesn't ship any prebuilt `mipsel` NaCl libc/libc++ to be used with Saigo so this is disabled.

Unlike PNaCl, Saigo doesn't compile to `pexe`, so the application code should be rebuilt as `nexe` for every target platform instead of compiling one `pexe` once and translating it to multiple `nexe` after that. The `pexe` to `nexe` translation being very slow, the iterative rebuild of three targets is faster anyway.

It also means precompiled `pexe` static libraries for various common libraries provided by Google (FreeType, etc.) cannot be used. Migrating a project to Saigo may then require to rebuild some dependencies.


## Limitations

Unlike PNaCl, Saigo may not support exceptions. There are some obvious exception-related files provided there and there, but we didn't got it working. We didn't got exceptions working with Google-built Saigo as well to begin with.

If you know how to make exceptions working, your contributions will be well appreciated.

Support for `setjmp`/`longjmp` is working.
