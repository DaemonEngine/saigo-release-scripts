# Dæmon Saigo Native Client Toolkit

Saigo is a new toolchain for compiling Native Client applications, Native Client was publicly abandonned by Google in 2020 in favor of WebAssembly, but Google silently continued development in the form of a new toolchain named Saigo. This project is to make possible to rebuild Native Client compilers for usage with the [Dæmon game engine](https://github.com/DaemonEngine/Daemon). The related project to rebuild the Native Client loader can [be found there](https://github.com/DaemonEngine/native_client).

## Status

It is now possible to rebuild the toolchain binaries (the NaCl Saigo Clang and related binutils), and to do it for more platforms than initially supported by Google. The toolchain binaries have been successfully built for:

||Linux|Windows|macOS|FreeBSD
-|-|-|-|-
amd64|✅️|✅️|✅️|✅️
i686|✅️|✅️|
arm64|✅️||✅️
armhf|✅️

The Windows build is meant to be cross-compiled on Linux using MinGW.

The libc and libc++ libraries are copied from pre-compiled libraries provided by Google.

Those libraries only contribute to binaries that run inside in the untrested environment of the Native Client virtual machine, meaning no pre-compiled code runs in the trusted environement outside of the Native Client virtual machine.

This project then already achieved the ability for someone to be able to recompile all the trusted code and then never have to run any precompiled trusted code.

The toolchain being buildable for some platforms only means it's possible to run the toolchain on those platforms to produce Native Client executables (nexe), it doesn't mean those Native Client executable can run on those platform. Running Native Client executables on new platforms would require new code in both the toolchain and the loader and it is not planned.

On platforms that can run the loader under some compatibility mode (like running 32-bit loader on 64-bit environment, or macOS running amd64 loader through Rosetta 2 on arm64, or FreeBSD running the Linux loader on Linuxulator, it means it makes possible to have a fully native toolchain to produce NaCl binaries (once the required libc and libc++ are installed too).

## How-to

### Single build

```
mkdir build && cd build
cmake ..
make -j32
```

A compiler toolchain can then be found in `build/prefix`.

The binutils build relies on autotools and GNU Make, so `gmake` has to be used instead of `make` on BSD systems.

Replace 32 with the amount of cores your computer provides. Rebuilding Clang requires a powerful computer (or very slow compilation is expected).

## Multi build

Using the `tools/release/build` wrapper only clones repositories once and then saves a lot of time and space.

On Linux:

```
tools/release/build linux-amd64 linux-i686 linux-arm64 linux-armhf windows-amd64 windows-i686
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

Despite the public depredaction and abandonment, Google continued development in the form of a brand new toolchain named Saigo.

History of NaCl toolchains, from older to newer:

- PNaCl GCC (GCC 4.4.3)
- PNaCl Clang (LLVM 3.6)
- Saigo Clang (LLVM 21 at the time of writing)

The Saigo toolchain is based on Clang and is frequently rebased over current LLVM, bringing latest Clang and latest C++ standards to NaCl, it also requires a special branch of binutils.

The libc++ is the one from the same recent LLVM Saigo is based on, and should be easy to build, unfortunately building some parts of the libc still requires the old GCC, which is very old and now hard to build, and Google themselves don't rebuild it in their scripts.


## Purpose

Purpose of this project is to provide a way to build native binaries for the toolchain running on developer's computer without relying on Google-provided binaries, this includes clang and the binutils. This would also allow to run the toolchain on systems not supported by Google. Google only build Saigo for `linux-amd64`, and Google only built PNaCl-clang for `linux-amd64`, `windows-amd64`, `windows-i686` and `macos-am64`.

For the nexe libc and libc++, this project aims to repackage the Google pre-compiled libraries in order to reach so minimimum viable product state. This precompiled code is meant to be executed in the NativeClient sandbox and then doesn't require the same level of trust.

Contributions making possible to fully rebuild the libc without any Google-provided binaries is welcome, though, but not as prioritary as providing a fully-rebuildable NaCl compiler toolchain environment.

Rebuilding the NaCl loader is investigated (don't hold your breath).


## Supported nexe target platforms

Here are the supported NaCl targets:

- `amd64`
- `i686`
- `arm`

Saigo itself can be built for mipsel, but Google doesn't ship any prebuilt mipsel libs for Saigo so this is disabled.

Unlike PNaCl, Saigo doesn't compile to pexe, so the code should be rebuilt for every target platform instead of compiling one pexe once and translating it to multiple nexe  after that. The pexe to nexe translation being very slow, the iterative rebuild of three targets is faster anyway.

It also means precompiled pexe static libraries for various common libraries provided by Google (FreeType, etc.) cannot be used. Migrating a project to Saigo may then require to rebuild some dependencies.


## Limitations

Unlike PNaCl, Saigo doesn't support exceptions, the Google scripts to build the libs actually do build some stuff for exceptions, but it doesn't work. Support for `setjmp`/`longjmp` is working.
