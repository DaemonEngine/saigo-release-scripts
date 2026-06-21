# Saigo Native Client compiler release scripts

This project makes possible to rebuild the Native Client compilers for usage with the [Dæmon game engine](https://github.com/DaemonEngine/Daemon).
The Dæmon engine is the open-source game engine powering the [Unvanquished game](https://unvanquished.net).

Saigo is a new toolchain for compiling Native Client applications.

Google publicly announced [in May of 2017](https://www.tomshardware.com/news/chrome-deprecates-pnacl-embraces-webassembly%2C34583.html) the (then-)upcoming deprecation and abandonment of Native Client technologies in favor of WebAssembly, and announced the actual deprecation [in 2020](https://developer.chrome.com/deprecated).
But Google also [supported](https://developer.chrome.com/docs/native-client) Native Client-powered ChromeOS 138, dropping it with ChromeOS 129 [in July of 2025](https://support.google.com/chrome/a/answer/10314655?&#139) and as such continued developpement of some Native Client technologies.
This extra development materialized in the maintenance of a toolchain named Saigo, frequently rebased on the latest LLVM upstream at the time. Saigo received commits from Google until January of 2025 and the last rebase was over Clang 21.

This repository doesn't contain any Saigo code, it provides scripts to build Saigo using Google upstream repositories:

- [chromium.googlesource.com/native_client/nacl-llvm-project-v10](https://chromium.googlesource.com/native_client/nacl-llvm-project-v10) (Saigo clang)
- [chromium.googlesource.com/native_client/nacl-binutils](https://chromium.googlesource.com/native_client/nacl-binutils) (Saigo binutils)

We provide patches (stored in this repository) the provided build scripts apply on upstream repositories before building. Those patches keep the tools buildables and makes them more cross-platform (buildable on more systems and architectures).

The related project to rebuild the Native Client loader (with NaCl client code and fixes) can be found there:

- [github.com/DaemonEngine/native_client](https://github.com/DaemonEngine/native_client)

In Japanese, Saigo (さいご / 最後) means “_the last_”, “_the end_”, “_the final_” or “_the conclusion_”. It refers to the end of an era, the final stage of an event, or the last item in a sequence.

Nothing about Native Client should be expected from Google anymore.


## Status

Component|Status
-|-
Saigo native clang|✅️ Rebuilt from scratch
Saigo native binutils|✅️ Rebuilt from scratch
Saigo nexe libc|☑️ Repackaged
Saigo nexe libc++|☑️ Repackaged

It is now possible to rebuild the toolchain binaries (the NaCl Saigo Clang and related binutils), and to do it for more platforms than initially supported by Google. The toolchain binaries have been successfully built for:

Architecture|Linux|Windows|macOS|FreeBSD
-|-|-|-|-
amd64|✅️|✅️|✅️|✅️
i686|✅️|✅️|
arm64|✅️||✅️
armhf|✅️
ppc64el|✅️
riscv4|✅️
loong64|✅️

This is only about running the native toolchain (building NaCl code), the NaCl loader (for running NaCl code) has stricter limitations.

The Windows build is meant to be cross-compiled on Linux using MinGW.

Those build scripts are only tested on Unix-like environment, the bash shell and standard coreutils are required.

For now, the libc and libc++ libraries are copied from pre-compiled libraries provided by Google.

Those libraries only contribute to binaries that run inside in the untrested environment of the Native Client virtual machine, meaning no pre-compiled code runs in the trusted environement outside of the Native Client virtual machine.

This project then already achieved the ability for someone to be able to recompile all the trusted code and then never have to run any precompiled trusted code.

The toolchain being buildable for some platforms only means it's possible to run the toolchain on those platforms to produce Native Client executables (nexe), it doesn't mean those Native Client executable can run on those platform. Running Native Client executables on new platforms would require new code in both the toolchain and the loader and this is not planned.

On platforms that can run the loader under some compatibility mode (like running 32-bit loader on 64-bit environment, or Linux running [box64](https://box86.org), or macOS running amd64 loader through Rosetta 2 on arm64, or FreeBSD running the Linux loader on Linuxulator, it means it makes possible to have a fully native toolchain to produce NaCl binaries (once the required libc and libc++ are installed too).


## How-to


### Single build

```
mkdir build && cd build
cmake ..
make -j32
```

A compiler toolchain can then be found in `build/prefix`.

The binutils build relies on autotools and GNU Make, so `gmake` has to be used instead of `make` on BSD systems.

Replace the 32 job count with the amount of cores your computer provides. Rebuilding Clang requires a powerful computer, as compilation is large and slow.

Building LLVM may require 8G per link task, especially when building it with LTO enabled, so you may prefer to use `RAM-size/8` as job count.


### Multi build

Using the `tools/release/build` wrapper only clones repositories once and then saves a lot of time and file space.

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


## History

History of NaCl toolchains, from older to newer (only the latest version of them being mentionned):

- PNaCl GCC (GCC 4.4.3)
- PNaCl Clang (LLVM 3.6)
- Saigo Clang (LLVM 21)

The Saigo toolchaini compiler is based on Clang and had been frequently rebased over the latest LLVM, bringing the latest Clang and latest C++ standards to NaCl at the time. Saigo clang has not been updated since January of 2025.

The Saigo toolchaon also requires a special branch of GNU binutils which hasn't been updated since November of 2014. We provide patches to make it more cross-platform.

The lastest version of Saigo is based on Clang 21 and as such we can expect C23 support and likely C2y partial draft support, C++23 support and likely C++2c partial draft support.

The libc++ is the one from the same recent LLVM Saigo is based on, and should be easy to build, unfortunately building some parts of the libc still requires the old GCC, which is very old and now hard to build, and Google themselves don't rebuild it in their scripts.

Out of convenience, the libc++ and libc is currently packaged from prebuilt packages by Google. The libc and the libc++ are linked to binaries running in the Native Client virtual machine and as such, never runs outside of the sandbox.

Everything that runs on the trusted machine (your machine) is rebuilt from scratch and no Google prebuilt binaries will be running on your computer when compiling the Saigo toolchain and when compiling NaCl code with the Saigo toolchain.


## Purpose

Purpose of this project is to provide a way to build native binaries for the toolchain running on developer's computer without:

- using Google-provided binaries to build NaCl code, that means clang and binutils are rebuilt from scratch;
- using Google-provided binaries to rebuild the toolchain itself,  that means means no Google binaries are used to build clang and binutils themselves.


This also allows to run the toolchain on systems not supported by Google. Google only build Saigo for `linux-amd64`, and Google only built PNaCl-clang for `linux-amd64`, `windows-amd64`, `windows-i686` and `macos-am64`.

While the Saigo toolchain can only build nexe for amd64, i686 and armhf, and there is no Native Client loaders for other architectures and other systems than Linux, Windows and macOS, those nexe and loaders can run on architecture and systems variants using compatibility layers. Those build scripts make possible to run a native Saigo toolchain where the NaCl loader can run through known compatibility layers.

System and Architecture|NaCl loader|Saigo toolchain
-|-|-
Linux amd64|✅️ native|✅️ native
Linux i686|✅️ native|✅️ native
Linux arm64|☑️ compatible (armhf multiarch, box64)|✅️ native
Linux armhf|✅ native|✅️ native
Linux ppc64el|☑️ compatible (box64)|✅️ native
Linux riscv64|☑️ compatible (box64)|✅️ native
Linux loong64|☑️ compatible (box64)|✅️ native
FreeBSD amd64|☑️ compatible (Linuxulator)|✅️ native
macOS amd64|✅️ native|✅️ native
macOS arm64|☑️ compatible (Rosetta 2)|✅️ native
Windows amd64|✅️ native|✅️ native
Windows i686|✅️ native|✅️ native

For the nexe libc and libc++, this project repackages the Google pre-compiled libraries in order to reach a minimimum viable product state. This precompiled code is meant to be executed within the Native Client sandbox and then doesn't require the same level of trust.

Contributions making possible to fully rebuild the libc without any Google-provided binaries is welcome, but is not as prioritary as providing a fully-rebuildable NaCl compiler toolchain environment.

Rebuilding the NaCl loader is possible thanks to another project:

- [github.com/DaemonEngine/native_client](https://github.com/DaemonEngine/native_client)


## Supported nexe target platforms

Here are the supported NaCl targets:

- `amd64`
- `i686`
- `arm`

Saigo itself can be built for `mipsel`, but Google doesn't ship any prebuilt `mipsel` libs for Saigo so this is disabled.

Unlike PNaCl, Saigo doesn't compile to `pexe`, so the code should be rebuilt as `nexe` for every target platform instead of compiling one `pexe` once and translating it to multiple `nexe` after that. The `pexe` to `nexe` translation being very slow, the iterative rebuild of three targets is faster anyway.

It also means precompiled `pexe` static libraries for various common libraries provided by Google (FreeType, etc.) cannot be used. Migrating a project to Saigo may then require to rebuild some dependencies.


## Limitations

Unlike PNaCl, Saigo may not support exceptions, the Google scripts to build the libs actually do build some stuff for exceptions, but it doesn't work. We didn't get extensions working with Google-built Saigo as well.

If you know how to make exceptions working, your contributions will be well appreciated.

Support for `setjmp`/`longjmp` is working.
