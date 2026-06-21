# Author: Thomas Debesse
# License: CC0 1.0

cmake_minimum_required(VERSION 3.10)

project(SaigoNativeClientToolchain LANGUAGES NONE)

include(ExternalProject)

if (NOT CLONE_SHARED_REPOSITORIES)
	enable_language(C)
	enable_language(CXX)

	include(CheckCompilerFlag)
	include(CheckLinkerFlag)

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

	find_program(PATH_CCACHE NAMES "ccache")
	find_program(PATH_NINJA NAMES "ninja")
	find_program(PATH_MOLD NAMES "mold")

	macro(FindTool SLUG FILE NAME)
		find_program(PATH_${SLUG} NAMES ${FILE})

		if (PATH_${SLUG})
			set(FOUND_${SLUG} ON)
		endif()

		option(USE_${SLUG} "Enable ${NAME} when possible." ${FOUND_${SLUG}})
	endmacro()

	FindTool("CCACHE" "ccache" "ccache compiler cache")
	FindTool("NINJA" "ninja" "ninja builder")
	FindTool("MOLD" "mold" "mold linker")

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

	if (CMAKE_OSX_DEPLOYMENT_TARGET)
		set(COMPILER_FLAGS "${COMPILER_FLAGS} -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
	endif()

	check_compiler_flag("C" "-mllvm --color" COMPILER_CLANG)

	option(USE_LTO "Enable link-time optimization." ON)

	if (USE_LTO AND NOT MINGW)
		if (COMPILER_CLANG)
			set(COMPILER_FLAGS "${COMPILER_FLAGS} -flto=thin -fno-fat-lto-objects")
		else()
			set(COMPILER_FLAGS "${COMPILER_FLAGS} -flto=auto -fno-fat-lto-objects")
		endif()

		set(EXE_LINKER_FLAGS "${EXE_LINKER_FLAGS} ${COMPILER_FLAGS}")
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_C_FLAGS}")
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
			ExternalProject_Add("${NAME}-directory"
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
		ExternalProject_Add("${NAME}-binaries"
			${EP_OPTIONS_${SLUG}}
			CONFIGURE_COMMAND echo
			BUILD_COMMAND rsync -av "${SOURCE_DIR_${SLUG}}/." "."
			INSTALL_COMMAND mkdir -p "${CMAKE_INSTALL_PREFIX}/${SUBDIR_${SLUG}}"
			INSTALL_COMMAND && rsync -av "." "${CMAKE_INSTALL_PREFIX}/${SUBDIR_${SLUG}}/."
			DOWNLOAD_EXTRACT_TIMESTAMP ON
		)

		add_dependencies(saigolibs ${NAME}-binaries)
	endif()
endmacro()

include(tarballs.cmake)

set(PATCH_BINUTILS
	git reset --hard origin/main
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0001-gprof-makefile-fix-building-m-files.patch
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0002-config-sub-enable-riscv64-and-loong64.patch
	&& git am ${CMAKE_SOURCE_DIR}/patches/binutils/0003-libiberty-waitpid-c-only-compile-waitpid-when-have-waitpid.patch
	&& git rebase --committer-date-is-author-date origin/main
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
	"main"
)

AddGitProject("binutils"
	"binutils"
	"https://chromium.googlesource.com/native_client/nacl-binutils.git"
	"main"
)

set(REFERENCE_ARCH_NAME x86_64)
set(ALIAS_BIN_ARCH_NAMES i686;arm)
set(ALIAS_DIR_ARCH_NAMES arm)

macro(RenameBinaryAliases targetName toolNames)
	add_custom_target(${targetName}-renames ALL)
	add_dependencies(${targetName} ${targetName}-renames)
	add_dependencies(${targetName}-renames ${targetName}-binaries)

	set(targetPath "${CMAKE_INSTALL_PREFIX}/bin/${targetName}${CMAKE_EXECUTABLE_SUFFIX}")
	set(referenceName "${targetName}-reference")
	set(referencePath "${EXTERNAL_PROJECT_BASE}/tmp/${referenceName}${CMAKE_EXECUTABLE_SUFFIX}")

	add_custom_target(${referenceName}
		ALL
		COMMAND cp -P "${targetPath}" "${referencePath}"
		DEPENDS ${targetName}-binaries
	)

	add_dependencies(${targetName} ${referenceName})

	foreach(toolName ${toolNames})
		set(aliasName "${REFERENCE_ARCH_NAME}-nacl-${toolName}")
		set(aliasPath "${CMAKE_INSTALL_PREFIX}/bin/${aliasName}${CMAKE_EXECUTABLE_SUFFIX}")

		add_custom_target(${aliasName}
			ALL
			COMMAND cp -P "${referencePath}" "${aliasPath}"
			DEPENDS ${referenceName}
		)

		add_dependencies(${targetName}-renames ${aliasName})
	endforeach()
endmacro()

macro(AddBinaryAliases targetName toolNames)
	add_custom_target(${targetName}-aliases ALL)
	add_dependencies(${targetName} ${targetName}-aliases)
	add_dependencies(${targetName}-aliases ${targetName}-binaries)

	foreach(archName ${ALIAS_BIN_ARCH_NAMES})
		foreach(toolName ${toolNames})
			set(referenceName "${REFERENCE_ARCH_NAME}-nacl-${toolName}${CMAKE_EXECUTABLE_SUFFIX}")
			set(aliasName "${archName}-nacl-${toolName}")
			set(aliasPath "${CMAKE_INSTALL_PREFIX}/bin/${aliasName}${CMAKE_EXECUTABLE_SUFFIX}")

			add_custom_target(${aliasName}
				ALL
				COMMAND ln -sf "${referenceName}" "${aliasPath}"
				DEPENDS ${targetName}-binaries
			)

			add_dependencies(${targetName}-aliases ${aliasName})
		endforeach()
	endforeach()
endmacro()

macro(AddDirectoryAliases targetName toolNames)
	add_custom_target(${targetName}-directory-aliases ALL)
	add_dependencies(${targetName} ${targetName}-directory-aliases)
	add_dependencies(${targetName}-directory-aliases ${targetName}-binaries)

	set(referenceName "${REFERENCE_ARCH_NAME}-nacl")

	foreach(archName ${ALIAS_DIR_ARCH_NAMES})
		set(aliasName "${archName}-nacl")
		set(aliasPath "${CMAKE_INSTALL_PREFIX}/${aliasName}")

		add_custom_target(${aliasName}-directory
			ALL
			COMMAND mkdir -p "${aliasPath}"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${targetName}-directory-aliases ${aliasName}-directory)

		add_custom_target(${aliasName}-bin-directory
			ALL
			COMMAND ln -sfn "../${referenceName}/bin" "${aliasPath}/bin"
			DEPENDS ${aliasName}-directory
		)

		add_dependencies(${targetName}-directory-aliases ${aliasName}-bin-directory)

		add_custom_target(${aliasName}-lib-directory
			ALL
			COMMAND mkdir -p "${aliasPath}/lib"
			DEPENDS ${aliasName}-directory
		)

		add_dependencies(${targetName}-directory-aliases ${aliasName}-lib-directory)

		add_custom_target(${aliasName}-ldscripts-directory
			ALL
			COMMAND ln -sfn "../../${referenceName}/lib/ldscripts" "${aliasPath}/lib/ldscripts"
			DEPENDS ${aliasName}-lib-directory
		)

		add_dependencies(${targetName}-directory-aliases ${aliasName}-ldscripts-directory)
	endforeach()

	foreach(toolName ${toolNames})
		set(toolPath "${CMAKE_INSTALL_PREFIX}/${referenceName}/bin/${toolName}")

		add_custom_target(${targetName}-${toolName}-delete
			ALL
			COMMAND rm -f "${toolPath}"
			DEPENDS ${targetName}-binaries
		)

		add_dependencies(${targetName}-directory-aliases ${targetName}-${toolName}-delete)

		add_custom_target(${targetName}-${toolName}-alias
			ALL
			COMMAND ln -sf "../../bin/${referenceName}-${toolName}" "${toolPath}"
			DEPENDS ${targetName}-${toolName}-delete
		)

		add_dependencies(${targetName}-directory-aliases ${targetName}-${toolName}-alias)
	endforeach()
endmacro()

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
			COMMAND rm -f
				"${deletePath}"
				"${deletePath}${CMAKE_EXECUTABLE_SUFFIX}"
				"${deletePath}.bat"
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

		set(libVersionSuffix ".21.0git")
		set(libVersionLongSuffix ".21.0.0git")

		if (WIN32)
			set(sharedLibDir "bin")
		else()
			set(sharedLibDir "lib")
		endif()

		set(sharedDeletePath "${CMAKE_INSTALL_PREFIX}/${sharedLibDir}/${libName}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		set(importDeletePath "${CMAKE_INSTALL_PREFIX}/lib/${libName}${CMAKE_IMPORT_LIBRARY_SUFFIX}")

		add_custom_target(${deleteName}
			ALL
			COMMAND rm -f
				"${sharedDeletePath}"
				"${sharedDeletePath}${libVersionSuffix}"
				"${sharedDeletePath}${libVersionLongSuffix}"
				"${importDeletePath}"
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
		)

		add_dependencies(${deletesName} ${deleteName})
	endforeach()
endfunction()

function(DeleteUselessLibexecDirectory targetName)
	set(deleteName ${targetName}-libexec-delete)

	set(deletePath "${CMAKE_INSTALL_PREFIX}/libexec")

	add_custom_target(${deleteName}
		ALL
		COMMAND rm -Rf "${deletePath}"
	)

	add_dependencies(${targetName} ${deleteName})
	add_dependencies(${deleteName} ${targetName}-binaries)
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

	ExternalProject_Add(clang-binaries
		${EP_OPTIONS_CLANG}
		SOURCE_SUBDIR llvm
		LIST_SEPARATOR |
		CMAKE_GENERATOR "${EP_GENERATOR}"
		CMAKE_ARGS "${EP_CMAKE_ARGS}"
		CMAKE_ARGS "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
		CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"
		CMAKE_ARGS "-DCMAKE_INSTALL_RPATH=${INSTALL_RPATH}"
		CMAKE_ARGS "-DCMAKE_C_COMPILER_LAUNCHER=${EP_COMPILER_LAUNCHER}"
		CMAKE_ARGS "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
		CMAKE_ARGS "-DCMAKE_C_FLAGS=${EP_C_FLAGS}"
		CMAKE_ARGS "-DCMAKE_CXX_COMPILER_LAUNCHER=${EP_COMPILER_LAUNCHER}"
		CMAKE_ARGS "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
		CMAKE_ARGS "-DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}"
		CMAKE_ARGS "-DCMAKE_EXE_LINKER_FLAGS=${EP_EXE_LINKER_FLAGS}"
		CMAKE_ARGS -DLLVM_APPEND_VC_REV=ON
		CMAKE_ARGS -DLLVM_BUILD_LLVM_DYLIB=OFF
		CMAKE_ARGS -DLLVM_BUILD_TESTS=OFF
		CMAKE_ARGS -DLLVM_ENABLE_PROJECTS=clang
		CMAKE_ARGS -DLLVM_ENABLE_LIBCXX=OFF
		CMAKE_ARGS -DLLVM_ENABLE_LIBXML2=OFF
		CMAKE_ARGS -DLLVM_ENABLE_Z3_SOLVER=OFF
		CMAKE_ARGS -DLLVM_ENABLE_ZLIB=OFF
		CMAKE_ARGS -DLLVM_ENABLE_ZSTD=OFF
		CMAKE_ARGS -DLLVM_ENABLE_RUNTIMES=
		CMAKE_ARGS -DLLVM_ENABLE_ASSERTIONS=OFF
		CMAKE_ARGS -DLLVM_USE_SYMLINKS=ON
		CMAKE_ARGS "-DLLVM_TARGETS_TO_BUILD=X86|ARM"
		CMAKE_ARGS "-DLLVM_DEFAULT_TARGET_TRIPLE=${TRIPLE_TARGET}"
		CMAKE_ARGS "-DLLVM_HOST_TRIPLE=${TRIPLE_HOST}"
		CMAKE_ARGS -DLLVM_INSTALL_UTILS=OFF
		CMAKE_ARGS -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON
		CMAKE_ARGS -DLLVM_LINK_LLVM_DYLIB=OFF
		CMAKE_ARGS -DCLANG_LINK_CLANG_DYLIB=OFF
		CMAKE_ARGS -DCLANG_INCLUDE_DOCS=OFF
		CMAKE_ARGS -DCLANG_INCLUDE_TESTS=OFF
		INSTALL_COMMAND ${CMAKE_COMMAND} --install . --strip
	)

	set(clangToolNames clang;clang++)

	RenameBinaryAliases(clang "${clangToolNames}")
	AddBinaryAliases(clang "${clangToolNames}")

	set(clangUselessToolNames amdgpu-arch;analyze-build;clang-check;clang-cl;clang-extdef-mapping;clang-format;clang-installapi;clang-linker-wrapper;clang-nvlink-wrapper;clang-offload-bundler;clang-offload-packager;clang-refactor;clang-repl;clang-scan-deps;clang-sycl-linker;diagtool;git-clang-format;hmaptool;intercept-build;llvm-ar;llvm-cov;llvm-cxxfilt;llvm-dlltool;llvm-dwp;llvm-lib;llvm-mca;llvm-ml;llvm-nm;llvm-objcopy;llvm-objdump;llvm-pdbutil;llvm-profdata;llvm-profgen;llvm-ranlib;llvm-rc;llvm-readobj;llvm-size;llvm-strings;llvm-strip;llvm-symbolizer;nvptx-arch;scan-build;scan-build-py;scan-view)

	DeleteUselessBinaries(clang "${clangUselessToolNames}")

	set(clangUselessLibraryNames libclang;libLTO;libRemarks)

	DeleteUselessLibraries(clang "${clangUselessLibraryNames}")

	set(clangUselessLibDirectoryNames libear;libscanbuild;cmake)

	DeleteUselessLibDirectories(clang "${clangUselessLibDirectoryNames}")

	DeleteUselessLibexecDirectory(clang)
endif()

macro(addConfigureEnv NAME VALUE)
	set(CONFIGURE_ENV ${CONFIGURE_ENV} "${NAME}=${VALUE}")
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

	if (NOT COMPILER_CLANG)
		set(STATIC_LIBGCC "-static-libstdc++ -static-libgcc")
	endif()

	ExternalProject_Add(binutils-binaries
		${EP_OPTIONS_BINUTILS}
		CONFIGURE_COMMAND "${SOURCE_DIR_BINUTILS}/configure"
		CONFIGURE_COMMAND ${CONFIGURE_ENV}
		CONFIGURE_COMMAND "CFLAGS=${EP_C_FLAGS} -Wno-absolute-value -Wno-unused-function -Wno-unused-const-variable -Wno-unneeded-internal-declaration -Wno-unused-private-field -Wno-format-security"
		CONFIGURE_COMMAND "LDFLAGS=${EP_EXE_LINKER_FLAGS} ${STATIC_LIBGCC}"
		CONFIGURE_COMMAND "--build=${TRIPLE_BUILD}"
		CONFIGURE_COMMAND "--host=${TRIPLE_HOST}"
		CONFIGURE_COMMAND "--target=${TRIPLE_TARGET}"
		CONFIGURE_COMMAND "--enable-targets=x86_64-nacl,i686-nacl,arm-nacl"
		CONFIGURE_COMMAND --prefix=
		# CONFIGURE_COMMAND --enable-gold --enable-plugins --disable-shared
		CONFIGURE_COMMAND --disable-gold
		CONFIGURE_COMMAND --disable-werror
		CONFIGURE_COMMAND --without-zlib
		CONFIGURE_COMMAND --disable-silent-rules
		CONFIGURE_COMMAND --enable-deterministic-archives
		BUILD_COMMAND $(MAKE)
		BUILD_COMMAND ${CONFIGURE_ENV}
		INSTALL_COMMAND $(MAKE)
		INSTALL_COMMAND ${CONFIGURE_ENV}
		INSTALL_COMMAND "DESTDIR=${CMAKE_INSTALL_PREFIX}"
		INSTALL_COMMAND install-strip
	)

	set(binutilsToolNames addr2line;ar;as;c++filt;elfedit;gprof;nm;objcopy;objdump;ranlib;readelf;size;strings;strip;ld;ld.bfd)
	set(binutilsDirectoryToolNames ar;as;ld;ld.bfd;nm;objcopy;objdump;ranlib;strip)

	AddBinaryAliases(binutils "${binutilsToolNames}")
	AddDirectoryAliases(binutils "${binutilsDirectoryToolNames}")

	add_custom_target(binutils-lib64-alias ALL
		COMMAND mkdir -p "${CMAKE_INSTALL_PREFIX}/x86_64-nacl"
		&& ln -sfn lib "${CMAKE_INSTALL_PREFIX}/x86_64-nacl/lib64"
	)

	add_dependencies(binutils-aliases binutils-lib64-alias)
endif()
