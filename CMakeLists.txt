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

# Some generated files (libraries) will get this strings,
# we don't control it, but we need to know it before hand.
set(SAIGO_CLANG_VERSION "21")

if (NOT CLONE_SHARED_REPOSITORIES)
	enable_language(C)
	enable_language(CXX)

	include(CheckCompilerFlag)
	include(CheckLinkerFlag)

	include(Yokai/Detection)

	set(FLAGS_LIST "${CMAKE_C_FLAGS}")
	separate_arguments(FLAGS_LIST)

	execute_process(
		COMMAND "${CMAKE_C_COMPILER}" ${FLAGS_LIST} -dumpmachine
		OUTPUT_VARIABLE TRIPLE_HOST
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)

	execute_process(
		COMMAND cc -dumpmachine
		OUTPUT_VARIABLE TRIPLE_BUILD
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)

	set(TRIPLE_TARGET x86_64-nacl)

	if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
		set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/prefix" CACHE PATH "Install path prefix, prepended onto install directories." FORCE)
	endif()

	get_property(CMAKE_BUILD_TYPE_HELP CACHE CMAKE_BUILD_TYPE PROPERTY HELPSTRING)
	set(CMAKE_BUILD_TYPE "Release" CACHE STRING "${CMAKE_BUILD_TYPE_HELP}" FORCE)
	set(CONFIGURE_COMPILER_FLAGS "-O3")

	macro(FindTool SLUG FILE NAME ENABLEMENT)
		find_program(PATH_${SLUG} NAMES ${FILE})

		set(DEFAULT_${SLUG} ${ENABLEMENT})

		if (NOT PATH_${SLUG})
				set(DEFAULT_${SLUG} OFF)
		endif()

		option(USE_${SLUG} "Enable ${NAME} when possible." ${DEFAULT_${SLUG}})
	endmacro()

	# Mold doesn't work properly on FreeBSD.
	if (YOKAI_HOST_SYSTEM_FREEBSD)
		set(DEFAULT_MOLD OFF)
	else()
		set(DEFAULT_MOLD ON)
	endif()

	FindTool("CCACHE" "ccache" "Ccache compiler cache" ON)
	FindTool("NINJA" "ninja" "Ninja builder" ON)
	FindTool("MOLD" "mold" "Mold linker" "${DEFAULT_MOLD}")

	if (USE_CCACHE)
		# Options come from LLVM CMakeLists.txt file.
		set(ENV${CCACHE_CPP2} "yes")
		set(ENV${CCACHE_HASHDIR} "yes")
		set(EP_COMPILER_LAUNCHER "ccache")
		set(EP_C_COMPILER "${EP_COMPILER_LAUNCHER} ${CMAKE_C_COMPILER}")
		set(EP_CXX_COMPILER "${EP_COMPILER_LAUNCHER} ${CMAKE_CXX_COMPILER}")
	else()
		set(EP_C_COMPILER "${CMAKE_C_COMPILER}")
		set(EP_CXX_COMPILER "${CMAKE_CXX_COMPILER}")
	endif()

	if (USE_NINJA)
		set(EP_GENERATOR "Ninja")
	else()
		set(EP_GENERATOR "${CMAKE_GENERATOR}")
	endif()

	if (USE_MOLD AND NOT MINGW)
		set(MOLD_FLAG "-fuse-ld=mold")
		check_linker_flag("C" ${MOLD_FLAG} FUSE_LD_MOLD)

		if (FUSE_LD_MOLD)
			set(COMPILER_FLAGS "${COMPILER_FLAGS} ${MOLD_FLAG}")
			set(EXE_LINKER_FLAGS "${EXE_LINKER_FLAGS} ${MOLD_FLAG}")
		endif()
	endif()

	if (YOKAI_TARGET_SYSTEM_MACOS)
		if (NOT CMAKE_OSX_DEPLOYMENT_TARGET STREQUAL "")
		set(COMPILER_FLAGS "${COMPILER_FLAGS} -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
	endif()
	endif()

	option(USE_LTO "Enable link-time optimization." OFF)

	if (USE_LTO)
		if (YOKAI_CXX_COMPILER_CLANG)
			set(FLTO_VALUE "thin")
		else()
			set(FLTO_VALUE "auto")
		endif()

		set(LTO_FLAGS "-flto=${FLTO_VALUE} -fno-fat-lto-objects")

		# FreeBSD and macOS clang don't support -fno-fat-lto-objects.
		set(LTO_FLAGS "${COMPILER_FLAGS} -Wno-ignored-optimization-argument")

		set(EXE_LINKER_FLAGS "${EXE_LINKER_FLAGS} ${COMPILER_FLAGS}")
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_C_FLAGS}")
	endif()

	if (YOKAI_CXX_COMPILER_GCC_COMPATIBILITY AND NOT YOKAI_CXX_COMPILER_CLANG_COMPATIBILITY)
		if (YOKAI_CXX_COMPILER_MINGW)
			string(APPEND EXE_LINKER_FLAGS " -static")
		endif()

		string(APPEND EXE_LINKER_FLAGS " -static-libstdc++ -static-libgcc")
	endif()

	set(EP_C_FLAGS "${CMAKE_C_FLAGS} ${COMPILER_FLAGS}")
	set(EP_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${COMPILER_FLAGS}")
	set(EP_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${EXE_LINKER_FLAGS}")
endif()

option(CLONE_SHARED_REPOSITORIES "Clone shared sources dir (and only do that)." OFF)

if (CLONE_SHARED_REPOSITORIES)
	set(DEFAULT_SHARED_REPOSITORIES "${CMAKE_CURRENT_BINARY_DIR}")
else()
	set(DEFAULT_SHARED_REPOSITORIES "")
endif()

set(SHARED_REPOSITORIES_DIR "${DEFAULT_SHARED_REPOSITORIES_DIR}" CACHE PATH "Shared repositories dir (doesn't use any if empty).")

set(EXTERNAL_PROJECT_BASE ExternalProjects)
set_directory_properties(PROPERTIES EP_BASE "${CMAKE_CURRENT_BINARY_DIR}/${EXTERNAL_PROJECT_BASE}")

if (CLONE_SHARED_REPOSITORIES)
	set(EXTERNAL_PROJECT_SOURCES_DIR "${CMAKE_BINARY_DIR}")
else()
	set(EXTERNAL_PROJECT_SOURCES_DIR "${EXTERNAL_PROJECT_BASE}/Sources")
endif()

option(BUILD_SAIGOLIBS "Build saigolibs." ON)

if (BUILD_SAIGOLIBS)
	add_custom_target(saigolibs ALL)
endif()

macro(AddTarProject NAME SUBDIR URL)
	list(APPEND LIBRARY_TARBALLS ${SLUG})
	string(TOUPPER "${NAME}" SLUG)
	set(DIR "${NAME}")
	set(SUBDIR_${SLUG} "${SUBDIR}")

	set(TARBALL_${SLUG} ${URL} CACHE STRING "${NAME} repository.")
	mark_as_advanced(TARBALL_${SLUG})

	if (SHARED_REPOSITORIES_DIR)
		set(SOURCE_DIR_${SLUG} "${SHARED_REPOSITORIES_DIR}/${DIR}")
	else()
		set(SOURCE_DIR_${SLUG} "${EXTERNAL_PROJECT_SOURCES_DIR}/${DIR}")
	endif()

	if (CLONE_SHARED_REPOSITORIES)
		option(CLONE_${SLUG} "Clone the ${NAME}." ON)

		if (CLONE_${SLUG})
			ExternalProject_Add("saigolibs-${NAME}-directory"
				URL "${URL}"
				SOURCE_DIR "${SOURCE_DIR_${SLUG}}"
				CONFIGURE_COMMAND echo
				BUILD_COMMAND echo
				INSTALL_COMMAND echo
				DOWNLOAD_EXTRACT_TIMESTAMP ON
			)
		endif()
	else()
		option(BUILD_${SLUG} "Build ${NAME}." ON)
	endif()

	if (SHARED_REPOSITORIES_DIR)
		set(SOURCE_DIR_${SLUG} ${SHARED_REPOSITORIES_DIR}/${DIR})

		set(EP_OPTIONS_${SLUG}
			SOURCE_DIR "${SOURCE_DIR_${SLUG}}"
		)
	else()
		set(EP_SOURCE_DIR_${SLUG} ${EXTERNAL_PROJECT_SOURCES_DIR}/${DIR})
		set(SOURCE_DIR_${SLUG} "${CMAKE_BINARY_DIR}/${EP_SOURCE_DIR_${SLUG}}")

		set(EP_OPTIONS_${SLUG}
			SOURCE_DIR "${EP_SOURCE_DIR_${SLUG}}"
			URL "${URL}"
		)
	endif()

	if (BUILD_SAIGOLIBS AND BUILD_${SLUG})
		ExternalProject_Add("saigolibs-${NAME}-binaries"
			${EP_OPTIONS_${SLUG}}
			CONFIGURE_COMMAND echo
			BUILD_COMMAND rsync -av "${SOURCE_DIR_${SLUG}}/." "."
			INSTALL_COMMAND
				mkdir -p "${CMAKE_INSTALL_PREFIX}/${SUBDIR_${SLUG}}"
				&& rsync -av "." "${CMAKE_INSTALL_PREFIX}/${SUBDIR_${SLUG}}/."
			DOWNLOAD_EXTRACT_TIMESTAMP ON
		)

		add_dependencies(saigolibs saigolibs-${NAME}-binaries)
	endif()
endmacro()

include(tarballs.cmake)

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

set(PATCH_BINUTILS
	git reset --hard "${REPOSITORY_TAG_BINUTILS}"
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0001-gprof-makefile-fix-building-m-files.patch
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0002-config-sub-enable-riscv64-and-loong64.patch
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0003-libiberty-waitpid-c-only-compile-waitpid-when-have-waitpid.patch
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0004-ld-makefile-in-do-not-build-libldtestplug-la-testplug-lo.patch
	&& git rebase --committer-date-is-author-date "${REPOSITORY_TAG_BINUTILS}"
)

set(PATCH_CLANG
	git reset --hard "${REPOSITORY_TAG_CLANG}"
	&& git am ${CMAKE_SOURCE_DIR}/patches/llvm-project/0001-cmake-accept-llvm-enable-lto-auto-option.patch
	&& git rebase --committer-date-is-author-date "${REPOSITORY_TAG_BINUTILS}"
)

macro(AddGitProject NAME DIR URL TAG)
	string(TOUPPER "${NAME}" SLUG)
	set(GIT_REPOSITORY_${SLUG} "${URL}" CACHE STRING "${NAME} git repository location.")
	mark_as_advanced(GIT_REPOSITORY_${SLUG})

	set(REPOSITORY_DIR_${SLUG} "${DIR}")
	set(REPOSITORY_TAG_${SLUG} "${TAG}")

	if (CLONE_SHARED_REPOSITORIES)
		option(CLONE_${SLUG} "Clone the ${NAME} repository." ON)

		if (CLONE_${SLUG})
			ExternalProject_Add("${REPOSITORY_DIR_${SLUG}}-shared-repository"
				SOURCE_DIR "${DIR}"
				GIT_REPOSITORY "${GIT_REPOSITORY_${SLUG}}"
				GIT_TAG "${TAG}"
				PATCH_COMMAND "${PATCH_${SLUG}}"
				CONFIGURE_COMMAND echo
				BUILD_COMMAND echo
				INSTALL_COMMAND echo
			)
		endif()
	else()
		option(BUILD_${SLUG} "Build the ${NAME}." ON)
	endif()

	if (SHARED_REPOSITORIES_DIR)
		set(SOURCE_DIR_${SLUG} "${SHARED_REPOSITORIES_DIR}/${DIR}")

		set(EP_OPTIONS_${SLUG}
			SOURCE_DIR "${SOURCE_DIR_${SLUG}}"
		)
	else()
		set(EP_SOURCE_DIR_${SLUG} "${EXTERNAL_PROJECT_SOURCES_DIR}/${DIR}")
		set(SOURCE_DIR_${SLUG} "${CMAKE_BINARY_DIR}/${EP_SOURCE_DIR_${SLUG}}")
		set(REPOSITORY_${SLUG} "${GIT_REPOSITORY_${SLUG}}")

		set(EP_OPTIONS_${SLUG}
			SOURCE_DIR "${EP_SOURCE_DIR_${SLUG}}"
			GIT_REPOSITORY "${REPOSITORY_${SLUG}}"
			GIT_TAG "${REPOSITORY_TAG_${SLUG}}"
			PATCH_COMMAND "${PATCH_${SLUG}}"
		)
	endif()
endmacro()

AddGitProject("clang"
	"llvm-project"
	"https://chromium.googlesource.com/native_client/nacl-llvm-project-v10.git"
	"9c7f0369cfdd591e580c5ccfc1f00fedee58029f"
)

AddGitProject("binutils"
	"binutils"
	"https://chromium.googlesource.com/native_client/nacl-binutils.git"
	"f009fc843ba7b9028f394725961bf899a172f45b"
)

set(REFERENCE_ARCH_NAME x86_64)
set(ALIAS_BIN_ARCH_NAMES i686;arm)
set(ALIAS_DIR_ARCH_NAMES arm)

function(RenameBinaryAliases targetName toolNames)
	set(renamesName ${targetName}-renames)
	add_custom_target(${renamesName} ALL)
	add_dependencies(${targetName} ${renamesName})
	add_dependencies(${renamesName} ${targetName}-binaries)

	set(targetPath "${CMAKE_INSTALL_PREFIX}/bin/${targetName}${CMAKE_EXECUTABLE_SUFFIX}")
	set(referenceName "${targetName}-reference")
	set(referencePath "${EXTERNAL_PROJECT_BASE}/tmp/${referenceName}${CMAKE_EXECUTABLE_SUFFIX}")

	add_custom_target(${referenceName}
		ALL
		COMMAND 
			rm -f "${referencePath}"
			&& cp -P "${targetPath}" "${referencePath}"
		DEPENDS ${targetName}-binaries
	)

	add_dependencies(${targetName} ${referenceName})

	foreach(toolName ${toolNames})
		set(aliasFile "${REFERENCE_ARCH_NAME}-nacl-${toolName}")
		set(aliasName "${targetName}-${aliasFile}")
		set(aliasPath "${CMAKE_INSTALL_PREFIX}/bin/${aliasFile}${CMAKE_EXECUTABLE_SUFFIX}")

		add_custom_target(${aliasName}
			ALL
			COMMAND
				rm -f "${aliasPath}"
				&& cp -P "${referencePath}" "${aliasPath}"
			DEPENDS ${referenceName}
		)

		add_dependencies(${renamesName} ${aliasName})
	endforeach()
endfunction()

function(AddBinaryAliases targetName toolNames)
	set(aliasesName ${targetName}-aliases)
	add_custom_target(${aliasesName} ALL)
	add_dependencies(${targetName} ${aliasesName})
	add_dependencies(${aliasesName} ${targetName}-binaries)

	foreach(archName ${ALIAS_BIN_ARCH_NAMES})
		foreach(toolName ${toolNames})
			set(referenceName "${REFERENCE_ARCH_NAME}-nacl-${toolName}${CMAKE_EXECUTABLE_SUFFIX}")
			set(aliasFile "${archName}-nacl-${toolName}")
			set(aliasName "${targetName}-${aliasFile}")
			set(aliasPath "${CMAKE_INSTALL_PREFIX}/bin/${aliasFile}${CMAKE_EXECUTABLE_SUFFIX}")

			add_custom_target(${aliasName}
				ALL
				COMMAND
					rm -f "${aliasPath}"
					&& ln -s "${referenceName}" "${aliasPath}"
				DEPENDS ${targetName}-binaries
			)

			add_dependencies(${aliasesName} ${aliasName})
		endforeach()
	endforeach()
endfunction()

function(AddDirectoryAliases targetName toolNames)
	set(aliasesName ${targetName}-directory-aliases)
	add_custom_target(${aliasesName} ALL)
	add_dependencies(${targetName} ${aliasesName})
	add_dependencies(${aliasesName} ${targetName}-binaries)

	set(referenceName "${REFERENCE_ARCH_NAME}-nacl")

	foreach(archName ${ALIAS_DIR_ARCH_NAMES})
		set(aliasDir "${archName}-nacl")
		set(aliasName "${targetName}-${aliasDir}")
		set(aliasPath "${CMAKE_INSTALL_PREFIX}/${aliasDir}")

		add_custom_target(${aliasName}-directory
			ALL
			COMMAND mkdir -p "${aliasPath}"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${aliasesName} ${aliasName}-directory)

		add_custom_target(${aliasName}-bin-directory
			ALL
			COMMAND
				rm -Rf "${aliasPath}/bin"
				&& ln -s "../${referenceName}/bin" "${aliasPath}/bin"
			DEPENDS ${aliasName}-directory
		)

		add_dependencies(${aliasesName} ${aliasName}-bin-directory)

		add_custom_target(${aliasName}-lib-directory
			ALL
			COMMAND mkdir -p "${aliasPath}/lib"
			DEPENDS ${aliasName}-directory
		)

		add_dependencies(${aliasesName} ${aliasName}-lib-directory)

		add_custom_target(${aliasName}-ldscripts-directory
			ALL
			COMMAND
				rm -Rf "${aliasPath}/lib/ldscripts"
				&& ln -s "../../${referenceName}/lib/ldscripts" "${aliasPath}/lib/ldscripts"
			DEPENDS ${aliasName}-lib-directory
		)

		add_dependencies(${aliasesName} ${aliasName}-ldscripts-directory)
	endforeach()

	foreach(toolName ${toolNames})
		set(toolPath "${CMAKE_INSTALL_PREFIX}/${referenceName}/bin/${toolName}${CMAKE_EXECUTABLE_SUFFIX}")
		set(referencePath "../../bin/${referenceName}-${toolName}${CMAKE_EXECUTABLE_SUFFIX}")

		add_custom_target(${targetName}-${toolName}-alias
			ALL
			COMMAND
				rm -f "${toolPath}"
				&& ln -s "${referencePath}" "${toolPath}"
			DEPENDS ${aliasName}-lib-directory
		)

		add_dependencies(${aliasesName} ${targetName}-${toolName}-alias)
	endforeach()
endfunction()

function(DeleteUselessBinaries targetName toolNames)
	set(deletesName ${targetName}-bin-deletes)
	add_custom_target(${deletesName} ALL)
	add_dependencies(${targetName} ${deletesName})
	add_dependencies(${deletesName} ${targetName}-binaries)

	foreach(toolName ${toolNames})
		set(deleteName "${targetName}-bin-${toolName}-delete")
		set(deletePath "${CMAKE_INSTALL_PREFIX}/bin/${toolName}")

		add_custom_target(${deleteName}
			ALL
			COMMAND
				rm -f
					"${deletePath}"
					"${deletePath}${CMAKE_EXECUTABLE_SUFFIX}"
					"${deletePath}.bat"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${deletesName} ${deleteName})
	endforeach()
endfunction()

function(DeleteUselessLibraries targetName libNames)
	set(deletesName "${targetName}-lib-deletes")
	add_custom_target(${deletesName} ALL)
	add_dependencies(${targetName} ${deletesName})
	add_dependencies(${deletesName} ${targetName}-binaries)

	foreach(libName ${libNames})
		set(deleteName "${targetName}-lib-${libName}-delete")

		set(libVersionSuffix ".${SAIGO_CLANG_VERSION}.0git")
		set(libVersionLongSuffix ".${SAIGO_CLANG_VERSION}.0.0git")

		if (WIN32)
			set(sharedLibDir "bin")
		else()
			set(sharedLibDir "lib")
		endif()

		set(sharedDeletePath "${CMAKE_INSTALL_PREFIX}/${sharedLibDir}/${libName}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		set(importDeletePath "${CMAKE_INSTALL_PREFIX}/lib/${libName}${CMAKE_IMPORT_LIBRARY_SUFFIX}")

		add_custom_target(${deleteName}
			ALL
			COMMAND
				rm -f
					"${sharedDeletePath}"
					"${sharedDeletePath}${libVersionSuffix}"
					"${sharedDeletePath}${libVersionLongSuffix}"
					"${importDeletePath}"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${deletesName} ${deleteName})
	endforeach()
endfunction()

function(DeleteUselessLibDirectories targetName dirNames)
	set(deletesName ${targetName}-libdir-deletes)
	add_custom_target(${deletesName} ALL)
	add_dependencies(${targetName} ${deletesName})
	add_dependencies(${deletesName} ${targetName}-binaries)

	foreach(dirName ${dirNames})
		set(deleteName "${targetName}-${dirName}-delete")

		set(deletePath "${CMAKE_INSTALL_PREFIX}/lib/${dirName}")

		add_custom_target(${deleteName}
			ALL
			COMMAND rm -Rf "${deletePath}"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${deletesName} ${deleteName})
	endforeach()
endfunction()

function(DeleteUselessDirectories targetName dirNames)
	set(deletesName ${targetName}-dir-deletes)
	add_custom_target(${deletesName} ALL)
	add_dependencies(${targetName} ${deletesName})
	add_dependencies(${deletesName} ${targetName}-binaries)

	foreach(dirName ${dirNames})
		set(deleteName "${targetName}-${dirName}-delete")

		set(deletePath "${CMAKE_INSTALL_PREFIX}/${dirName}")

		add_custom_target(${deleteName}
			ALL
			COMMAND rm -Rf "${deletePath}"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${deletesName} ${deleteName})
	endforeach()
endfunction()

if (CMAKE_OSX_DEPLOYMENT_TARGET)
	list(APPEND EP_CMAKE_ARGS "-DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

if (CMAKE_TOOLCHAIN_FILE)
	list(APPEND EP_CMAKE_ARGS "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
else()
	# This is expected when cross-compiling, also sets CMAKE_CROSSCOMPILING.
	# See: https://llvm.org/docs/HowToCrossCompileLLVM.html
	list(APPEND EP_CMAKE_ARGS "-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}")
endif()

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

set(STATIC_LIBGCC "-static-libstdc++ -static-libgcc")

if (BUILD_BINUTILS)
	add_custom_target(binutils ALL)

	set(BINUTILS_C_FLAGS "-Wno-absolute-value -Wno-unused-function -Wno-unused-const-variable -Wno-unneeded-internal-declaration -Wno-unused-private-field -Wno-format-security")

	set(BINUTILS_EXE_LINKER_FLAGS)

	if (NOT COMPILER_CLANG)
		string(APPEND BINUTILS_EXE_LINKER_FLAGS " ${STATIC_LIBGCC}")
	endif()

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

add_custom_target(distclean
    COMMAND
		${CMAKE_COMMAND} -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/prefix"
		&& ${CMAKE_COMMAND} --build "${CMAKE_CURRENT_BINARY_DIR}" --target clean
)
