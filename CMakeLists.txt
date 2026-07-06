# Copyright (c) 2024-2026 Daemon Developers
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

cmake_minimum_required(VERSION 3.10)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

project(SaigoNativeClientToolchain LANGUAGES NONE)

include(ExternalProject)

include(SaigoSetup)
include(SaigoHelpers)

# Some generated files (libraries) will get this strings,
# we don't control it, but we need to know it before hand.
set(SAIGO_CLANG_VERSION "21")

AddGitProject("clang"
	"llvm-project"
	"https://chromium.googlesource.com/native_client/nacl-llvm-project-v10.git"
	"9c7f0369cfdd591e580c5ccfc1f00fedee58029f"
	"0001-cmake-accept-llvm-enable-lto-auto-option.patch"
)

AddGitProject("binutils"
	"binutils"
	"https://chromium.googlesource.com/native_client/nacl-binutils.git"
	"f009fc843ba7b9028f394725961bf899a172f45b"
	"0001-gprof-makefile-fix-building-m-files.patch"
	"0002-config-sub-enable-riscv64-and-loong64.patch"
	"0003-libiberty-waitpid-c-only-compile-waitpid-when-have-waitpid.patch"
	"0004-ld-makefile-in-do-not-build-libldtestplug-la-testplug-lo.patch"
)

include(saigolibs-tarballs.cmake)

set(REFERENCE_SYSTEM_NAME "nacl")
set(REFERENCE_ARCH_NAME "x86_64")
set(ALIAS_BIN_ARCH_NAMES "i686" "arm")
set(ALIAS_DIR_ARCH_NAMES "arm")

if (BUILD_CLANG)
	add_custom_target(clang ALL)

	if (APPLE)
		set(INSTALL_RPATH "$ORIGIN/../lib")
	else()
		set(INSTALL_RPATH "@executable_path/../lib")
	endif()

	if (USE_LTO)
		if (NOT MINGW)
			set(LLVM_LTO "${FLTO_VALUE}")
		endif()
	else()
		set(LLVM_LTO "OFF")
	endif()

	ExternalProject_Add(clang-binaries
		${EP_OPTIONS_CLANG}
		SOURCE_SUBDIR llvm
		LIST_SEPARATOR |
		CMAKE_GENERATOR "${EP_GENERATOR}"
		CMAKE_ARGS
			"${EP_CMAKE_ARGS}"
			"-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			"-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
			"-DCMAKE_INSTALL_RPATH=${INSTALL_RPATH}"
			"-DCMAKE_C_COMPILER_LAUNCHER=${EP_COMPILER_LAUNCHER}"
			"-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
			"-DCMAKE_C_FLAGS=${EP_C_FLAGS}"
			"-DCMAKE_CXX_COMPILER_LAUNCHER=${EP_COMPILER_LAUNCHER}"
			"-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
			"-DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}"
			"-DCMAKE_EXE_LINKER_FLAGS=${EP_EXE_LINKER_FLAGS}"
			-DLLVM_APPEND_VC_REV=ON
			-DLLVM_BUILD_LLVM_DYLIB=OFF
			-DLLVM_BUILD_UTILS=OFF
			-DLLVM_BUILD_TESTS=OFF
			-DLLVM_INCLUDE_UTILS=OFF
			-DLLVM_INCLUDE_TESTS=OFF
			-DLLVM_ENABLE_PROJECTS=clang
			-DLLVM_ENABLE_LIBCXX=OFF
			-DLLVM_ENABLE_LIBXML2=OFF
			-DLLVM_ENABLE_Z3_SOLVER=OFF
			-DLLVM_ENABLE_ZLIB=OFF
			-DLLVM_ENABLE_ZSTD=OFF
			-DLLVM_ENABLE_RUNTIMES=
			-DLLVM_ENABLE_ASSERTIONS=OFF
			"-DLLVM_ENABLE_LTO=${LLVM_LTO}"
			-DLLVM_USE_SYMLINKS=ON
			"-DLLVM_TARGETS_TO_BUILD=X86|ARM"
			"-DLLVM_DEFAULT_TARGET_TRIPLE=${TRIPLE_TARGET}"
			"-DLLVM_HOST_TRIPLE=${TRIPLE_HOST}"
			-DLLVM_INSTALL_UTILS=OFF
			-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON
			-DLLVM_LINK_LLVM_DYLIB=OFF
			-DCLANG_LINK_CLANG_DYLIB=OFF
			-DCLANG_INCLUDE_DOCS=OFF
			-DCLANG_INCLUDE_TESTS=OFF
		INSTALL_COMMAND ${CMAKE_COMMAND} --install . --strip
	)

	add_dependencies(clang clang-binaries)

	set(clangToolNames clang;clang++)

	RenameBinaryAliases(clang "${clangToolNames}")
	AddBinaryAliases(clang "${clangToolNames}")

	set(clangUselessToolNames amdgpu-arch;analyze-build;clang-check;clang-cl;clang-extdef-mapping;clang-format;clang-installapi;clang-linker-wrapper;clang-nvlink-wrapper;clang-offload-bundler;clang-offload-packager;clang-refactor;clang-repl;clang-scan-deps;clang-sycl-linker;diagtool;git-clang-format;hmaptool;intercept-build;llvm-ar;llvm-cov;llvm-cxxfilt;llvm-dlltool;llvm-dwp;llvm-lib;llvm-mca;llvm-ml;llvm-nm;llvm-objcopy;llvm-objdump;llvm-pdbutil;llvm-profdata;llvm-profgen;llvm-ranlib;llvm-rc;llvm-readobj;llvm-size;llvm-strings;llvm-strip;llvm-symbolizer;nvptx-arch;scan-build;scan-build-py;scan-view)

	DeleteUselessBinaries(clang "${clangUselessToolNames}")

	set(clangUselessLibraryNames libclang;libLTO;libRemarks)

	DeleteUselessLibraries(clang "${clangUselessLibraryNames}")

	set(clangUselessLibDirectoryNames libear;libscanbuild;cmake)

	DeleteUselessLibDirectories(clang "${clangUselessLibDirectoryNames}")

	set(clangUselessDirectoryNames include;libexec;share)

	DeleteUselessDirectories(clang "${clangUselessDirectoryNames}")
endif()

macro(addConfigureEnv NAME VALUE)
	list(APPEND CONFIGURE_ENV "${NAME}=${VALUE}")
endmacro()

macro(addBinutilEnv NAME PATH)
	set(TRIPLE_${NAME} "${TRIPLE_HOST}-${PATH}")

	find_program(PATH_TRIPLE_${NAME} NAMES "${TRIPLE_${NAME}}")

	if (PATH_TRIPLE_${NAME})
		set(BINUTIL_${NAME} "${TRIPLE_${NAME}}")
	else ()
		set(BINUTIL_${NAME} "${PATH}")
		addConfigureEnv("${NAME}" "${PATH}")
	endif()
endmacro()

addBinutilEnv("AR" "ar")
addBinutilEnv("NM" "nm")
addBinutilEnv("OBJDUMP" "objdump")
addBinutilEnv("RANLIB" "ranlib")
addBinutilEnv("STRIP" "strip")

addConfigureEnv("CC" "${EP_C_COMPILER}")
addConfigureEnv("CC_FOR_BUILD" "cc")
addConfigureEnv("MAKEINFO" "true")
addConfigureEnv("STRIPPROG" "${BINUTIL_STRIP}")

if (BUILD_BINUTILS)
	add_custom_target(binutils ALL)

	set(BINUTILS_C_FLAGS "-Wno-absolute-value -Wno-unused-function -Wno-unused-const-variable -Wno-unneeded-internal-declaration -Wno-unused-private-field -Wno-format-security")

	set(BINUTILS_EXE_LINKER_FLAGS)

	if (USE_LTO)
		string(APPEND BINUTILS_C_FLAGS " ${LTO_FLAGS}")

		if (MINGW)
			string(APPEND BINUTILS_C_FLAGS " -Dffs=__builtin_ffs")
		endif()
	endif()

	set(BINUTILS_ENV
		${CONFIGURE_ENV}
		"CFLAGS=${EP_C_FLAGS} ${CONFIGURE_COMPILER_FLAGS} ${BINUTILS_C_FLAGS}"
		"LDFLAGS=${EP_EXE_LINKER_FLAGS} ${BINUTILS_EXE_LINKER_FLAGS}"
	)

	ExternalProject_Add(binutils-binaries
		${EP_OPTIONS_BINUTILS}
		CONFIGURE_COMMAND
			"${SOURCE_DIR_BINUTILS}/configure"
				${BINUTILS_ENV}
				"--build=${TRIPLE_BUILD}"
				"--host=${TRIPLE_HOST}"
				"--target=${TRIPLE_TARGET}"
				"--enable-targets=x86_64-nacl,i686-nacl,arm-nacl"
				--prefix=
				--disable-gold
				--disable-werror
				--disable-nls
				--without-zlib
				--disable-silent-rules
				--disable-gdb
				--disable-plugins
				--disable-sim
				--disable-testsuite
				--enable-deterministic-archives
		BUILD_COMMAND
			$(MAKE)
				${BINUTILS_ENV}
		INSTALL_COMMAND
			$(MAKE)
				${BINUTILS_ENV}
				"DESTDIR=${CMAKE_INSTALL_PREFIX}"
				install-strip
	)

	add_dependencies(binutils binutils-binaries)

	set(binutilsToolNames addr2line;ar;as;c++filt;elfedit;gprof;nm;objcopy;objdump;ranlib;readelf;size;strings;strip;ld;ld.bfd)
	set(binutilsDirectoryToolNames ar;as;ld;ld.bfd;nm;objcopy;objdump;ranlib;strip)

	AddBinaryAliases(binutils "${binutilsToolNames}")
	AddDirectoryAliases(binutils "${binutilsDirectoryToolNames}")

	add_custom_target(binutils-lib64-alias
		ALL
		COMMAND
			mkdir -p "${CMAKE_INSTALL_PREFIX}/x86_64-nacl"
			&& ln -sfn lib "${CMAKE_INSTALL_PREFIX}/x86_64-nacl/lib64"
		DEPENDS binutils-binaries
	)

	add_dependencies(binutils-aliases binutils-lib64-alias)
endif()

if (BUILD_SAIGOLIBS)
	# x86_64-nacl/include and arm-nacl/include are exactly the same
	# but exactly one header more in x86_64-nacl/include:
	#   dynamic_annotations.h
	# x86_64-nacl/share and arm-nacl/share are exactly the same

	add_custom_target(saigolibs-arm-core-alias
		ALL
		COMMAND
			rm -Rf "${CMAKE_INSTALL_PREFIX}/arm-nacl/include"
			&& ln -s "../x86_64-nacl/include" "${CMAKE_INSTALL_PREFIX}/arm-nacl/include"
		DEPENDS saigolibs-x86_64-core-binaries saigolibs-arm-core-binaries
			saigolibs-x86_64-libcxx-binaries saigolibs-arm-libcxx-binaries
	)

	add_custom_target(saigolibs-arm-libcxx-alias
		ALL
		COMMAND
			rm -Rf "${CMAKE_INSTALL_PREFIX}/arm-nacl/share"
			&& ln -s "../x86_64-nacl/share" "${CMAKE_INSTALL_PREFIX}/arm-nacl/share"
		DEPENDS saigolibs-x86_64-libcxx-binaries saigolibs-arm-libcxx-binaries
	)

	add_custom_target(saigolibs-aliases)
	add_dependencies(saigolibs saigolibs-aliases)
	add_dependencies(saigolibs-aliases saigolibs-arm-core-alias)
	add_dependencies(saigolibs-aliases saigolibs-arm-libcxx-alias)
endif()

add_custom_target(distclean
    COMMAND
		${CMAKE_COMMAND} -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/prefix"
		&& ${CMAKE_COMMAND} --build "${CMAKE_CURRENT_BINARY_DIR}" --target clean
)
