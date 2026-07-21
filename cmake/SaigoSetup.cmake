set(PATCHES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/patches")

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

if (CLONE_SHARED_REPOSITORIES)
	set(DEFAULT_BUILD OFF)
else()
	set(DEFAULT_BUILD ON)
endif()

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
		set(CMAKE_INSTALL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/install" CACHE PATH "Install path prefix, prepended onto install directories." FORCE)
	endif()

	get_property(CMAKE_BUILD_TYPE_HELP CACHE CMAKE_BUILD_TYPE PROPERTY HELPSTRING)
	set(CMAKE_BUILD_TYPE "Release" CACHE STRING "${CMAKE_BUILD_TYPE_HELP}" FORCE)
	set(CONFIGURE_COMPILER_FLAGS "-O3")

	# Mold doesn't work properly on FreeBSD.
	if (YOKAI_HOST_SYSTEM_FREEBSD)
		set(DEFAULT_MOLD OFF)
	else()
		set(DEFAULT_MOLD ON)
	endif()

	FindTool("CCACHE" "ccache" "Ccache compiler cache" ON)
	FindTool("ICECC" "icecc" "IceCream distributed compiler scheduler" ON)
	FindTool("NINJA" "ninja" "Ninja builder" ON)
	FindTool("MOLD" "mold" "Mold linker" "${DEFAULT_MOLD}")

	if (USE_CCACHE)
		set(EP_COMPILER_LAUNCHER "${PATH_CCACHE}")

		# Options come from the LLVM CMakeLists.txt file:
		list(APPEND BUILD_ENV "CCACHE_CPP2=true")
		list(APPEND BUILD_ENV "CCACHE_HASHDIR=true")

		if (USE_ICECC)
			list(APPEND BUILD_ENV "CCACHE_PREFIX=${PATH_ICECC}")
		endif()

	elseif (USE_ICECC)
		set(EP_COMPILER_LAUNCHER "${PATH_ICECC}")
	endif()

	if (USE_NINJA)
		set(EP_GENERATOR "Ninja")
		list(APPEND EP_CMAKE_ARGS "-DCMAKE_MAKE_PROGRAM=${PATH_NINJA}")
	else()
		set(EP_GENERATOR "${CMAKE_GENERATOR}")
	endif()

	if (USE_MOLD)
		set(MOLD_FLAG "-fuse-ld=mold")
		check_linker_flag("C" "LINKER:${MOLD_FLAG}" FUSE_LD_MOLD)

		if (FUSE_LD_MOLD)
			list(APPEND COMPILER_FLAGS "-Wl,${MOLD_FLAG}")
			list(APPEND EXE_LINKER_FLAGS "${MOLD_FLAG}")
		endif()
	endif()

	if (YOKAI_TARGET_SYSTEM_MACOS)
		if (NOT "${CMAKE_OSX_DEPLOYMENT_TARGET}" STREQUAL "")
			list(APPEND COMPILER_FLAGS "-mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
		endif()
	endif()

	if (YOKAI_TARGET_SYSTEM_MACOS)
		set(INSTALL_RPATH "$ORIGIN/../lib")
	else()
		set(INSTALL_RPATH "@executable_path/../lib")
	endif()

	option(USE_LTO "Enable link-time optimization." OFF)

	if (USE_LTO)
		if (YOKAI_CXX_COMPILER_CLANG)
			set(FLTO_VALUE "thin")
		else()
			set(FLTO_VALUE "auto")
		endif()

		list(APPEND LTO_FLAGS "-flto=${FLTO_VALUE}" "-fno-fat-lto-objects")

		# FreeBSD and macOS clang don't support -fno-fat-lto-objects.
		list(APPEND LTO_FLAGS "-Wno-ignored-optimization-argument")

		foreach(flag IN ITEMS ${CMAKE_C_FLAGS})
			list(APPEND EXE_LINKER_FLAGS ${flag})
		endforeach()

		list(APPEND EXE_LINKER_FLAGS ${COMPILER_FLAGS})
	endif()

	if (YOKAI_CXX_COMPILER_MINGW)
		list(APPEND EXE_LINKER_FLAGS "-static" "-static-libstdc++" "-static-libgcc")
	endif()

	foreach(flag IN ITEMS ${CMAKE_C_FLAGS})
		list(APPEND EP_C_FLAGS "${flag}")
	endforeach()

	foreach(flag IN ITEMS ${CMAKE_CXX_FLAGS})
		list(APPEND EP_CXX_FLAGS "${flag}")
	endforeach()

	foreach(flag IN ITEMS ${CMAKE_EXE_LINKER_FLAGS})
		list(APPEND EP_EXE_LINKER_FLAGS "${flag}")
	endforeach()

	list(APPEND EP_C_FLAGS ${COMPILER_FLAGS})
	list(APPEND EP_CXX_FLAGS ${COMPILER_FLAGS})
	list(APPEND EP_EXE_LINKER_FLAGS ${EXE_LINKER_FLAGS})

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

	set(EP_C_COMPILER "${CMAKE_C_COMPILER}")
	set(EP_CXX_COMPILER "${CMAKE_CXX_COMPILER}")

	AddToolConfigureEnv("CC" "${EP_COMPILER_LAUNCHER} ${EP_C_COMPILER}")
	AddToolConfigureEnv("CXX" "${EP_COMPILER_LAUNCHER} ${EP_CXX_COMPILER}")

	AddTripleToolConfigureEnv("AR" "ar")
	AddTripleToolConfigureEnv("NM" "nm")
	AddTripleToolConfigureEnv("OBJDUMP" "objdump")
	AddTripleToolConfigureEnv("RANLIB" "ranlib")
	AddTripleToolConfigureEnv("STRIP" "strip")

	ListToString("EP_C_FLAGS")
	ListToString("EP_CXX_FLAGS")
	ListToString("EP_EXE_LINKER_FLAGS")
	ListToString("LTO_FLAGS")
endif()
