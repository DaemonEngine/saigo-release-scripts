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

include(SaigoHelpers)
include(SaigoSetup)

# Some generated files will have this string in their name,
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

AddGitProject("nacl"
	"native_client"
	"https://github.com/DaemonEngine/native_client.git"
	"ae29840014b5c08c7733ee9257741d421723255a"
)

include(saigolibs-tarballs.cmake)

set(REFERENCE_SYSTEM_NAME "nacl")
set(REFERENCE_ARCH_NAME "x86_64")
set(ALIAS_BIN_ARCH_NAMES "i686" "arm")
set(ALIAS_DIR_ARCH_NAMES "arm")

if (BUILD_CLANG)
	if (USE_LTO)
		if (NOT MINGW)
			set(LLVM_LTO "${FLTO_VALUE}")
		endif()
	else()
		set(LLVM_LTO "OFF")
	endif()

	set(ENV{CCACHE_PREFIX} "${PATH_ICECC}")

	AddCompilerCmakeArgs(CLANG "C;CXX")

	list(APPEND CLANG_ARGS ${EP_CMAKE_ARGS})

	ExternalProject_Add(clang-binaries
		${EP_OPTIONS_CLANG}
		SOURCE_SUBDIR llvm
		LIST_SEPARATOR "|"
		CMAKE_GENERATOR "${EP_GENERATOR}"
		CMAKE_ARGS
			${CLANG_ARGS}

			"-DLLVM_TARGETS_TO_BUILD=X86|ARM"
			"-DLLVM_DEFAULT_TARGET_TRIPLE=${TRIPLE_TARGET}"
			"-DLLVM_HOST_TRIPLE=${TRIPLE_HOST}"
			"-DLLVM_CCACHE_BUILD=${USE_CCACHE}"
			"-DLLVM_ENABLE_LTO=${LLVM_LTO}"

			-DCLANG_LINK_CLANG_DYLIB=OFF
			-DCLANG_INCLUDE_DOCS=OFF
			-DCLANG_INCLUDE_TESTS=OFF

			-DLLVM_APPEND_VC_REV=OFF
			-DLLVM_BUILD_LLVM_DYLIB=OFF
			-DLLVM_BUILD_TESTS=OFF
			-DLLVM_BUILD_UTILS=OFF
			-DLLVM_ENABLE_ASSERTIONS=OFF
			-DLLVM_ENABLE_LIBCXX=OFF
			-DLLVM_ENABLE_LIBXML2=OFF
			-DLLVM_ENABLE_PROJECTS=clang
			-DLLVM_ENABLE_RUNTIMES=
			-DLLVM_ENABLE_Z3_SOLVER=OFF
			-DLLVM_ENABLE_ZLIB=OFF
			-DLLVM_ENABLE_ZSTD=OFF
			-DLLVM_INCLUDE_TESTS=OFF
			-DLLVM_INCLUDE_UTILS=OFF
			-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON
			-DLLVM_INSTALL_UTILS=OFF
			-DLLVM_LINK_LLVM_DYLIB=OFF
			-DLLVM_USE_SYMLINKS=ON

			-DCLANG_TOOL_AMDGPU_ARCH_BUILD=OFF
			-DCLANG_TOOL_APINOTES_TEST_BUILD=OFF
			-DCLANG_TOOL_CLANG_CHECK_BUILD=OFF
			-DCLANG_TOOL_CLANG_DIFF_BUILD=OFF
			-DCLANG_TOOL_CLANG_EXTDEF_MAPPING_BUILD=OFF
			-DCLANG_TOOL_CLANG_FORMAT_BUILD=OFF
			-DCLANG_TOOL_CLANG_FUZZER_BUILD=OFF
			-DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF
			-DCLANG_TOOL_CLANG_INSTALLAPI_BUILD=OFF
			-DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF
			-DCLANG_TOOL_CLANG_NVLINK_WRAPPER_BUILD=OFF
			-DCLANG_TOOL_CLANG_OFFLOAD_BUNDLER_BUILD=OFF
			-DCLANG_TOOL_CLANG_OFFLOAD_PACKAGER_BUILD=OFF
			-DCLANG_TOOL_CLANG_REFACTOR_BUILD=OFF
			-DCLANG_TOOL_CLANG_REPL_BUILD=OFF
			-DCLANG_TOOL_CLANG_SCAN_DEPS_BUILD=OFF
			-DCLANG_TOOL_CLANG_SHLIB_BUILD=OFF
			-DCLANG_TOOL_CLANG_SYCL_LINKER_BUILD=OFF
			-DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF
			-DCLANG_TOOL_DIAGTOOL_BUILD=OFF
			-DCLANG_TOOL_DICTIONARY_BUILD=OFF
			-DCLANG_TOOL_DRIVER_BUILD=ON
			-DCLANG_TOOL_HANDLE_CXX_BUILD=OFF
			-DCLANG_TOOL_HANDLE_LLVM_BUILD=OFF
			-DCLANG_TOOL_LIBCLANG_BUILD=OFF
			-DCLANG_TOOL_NVPTX_ARCH_BUILD=OFF
			-DCLANG_TOOL_SCAN_BUILD_BUILD=OFF
			-DCLANG_TOOL_SCAN_BUILD_PY_BUILD=OFF
			-DCLANG_TOOL_SCAN_VIEW_BUILD=OFF

			-DLLVM_TOOL_BOLT_BUILD=OFF
			-DLLVM_TOOL_BUGPOINT_BUILD=OFF
			-DLLVM_TOOL_BUGPOINT_PASSES_BUILD=OFF
			-DLLVM_TOOL_CLANG_BUILD=ON
			-DLLVM_TOOL_CLANG_TOOLS_EXTRA_BUILD=OFF
			-DLLVM_TOOL_COMPILER_RT_BUILD=OFF
			-DLLVM_TOOL_CROSS_PROJECT_TESTS_BUILD=OFF
			-DLLVM_TOOL_DRAGONEGG_BUILD=OFF
			-DLLVM_TOOL_DSYMUTIL_BUILD=OFF
			-DLLVM_TOOL_DXIL_DIS_BUILD=OFF
			-DLLVM_TOOL_FLANG_BUILD=OFF
			-DLLVM_TOOL_GOLD_BUILD=OFF
			-DLLVM_TOOL_LIBC_BUILD=OFF
			-DLLVM_TOOL_LIBCLC_BUILD=OFF
			-DLLVM_TOOL_LIBCXXABI_BUILD=OFF
			-DLLVM_TOOL_LIBCXX_BUILD=OFF
			-DLLVM_TOOL_LIBUNWIND_BUILD=OFF
			-DLLVM_TOOL_LLC_BUILD=OFF
			-DLLVM_TOOL_LLDB_BUILD=OFF
			-DLLVM_TOOL_LLD_BUILD=OFF
			-DLLVM_TOOL_LLI_BUILD=OFF
			-DLLVM_TOOL_LTO_BUILD=OFF
			-DLLVM_TOOL_MLIR_BUILD=OFF
			-DLLVM_TOOL_OBJ2YAML_BUILD=OFF
			-DLLVM_TOOL_OPENMP_BUILD=OFF
			-DLLVM_TOOL_OPT_BUILD=OFF
			-DLLVM_TOOL_OPT_VIEWER_BUILD=OFF
			-DLLVM_TOOL_POLLY_BUILD=OFF
			-DLLVM_TOOL_PSTL_BUILD=OFF
			-DLLVM_TOOL_REDUCE_CHUNK_LIST_BUILD=OFF
			-DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF
			-DLLVM_TOOL_SANCOV_BUILD=OFF
			-DLLVM_TOOL_SANSTATS_BUILD=OFF
			-DLLVM_TOOL_SPIRV_TOOLS_BUILD=OFF
			-DLLVM_TOOL_VERIFY_USELISTORDER_BUILD=OFF
			-DLLVM_TOOL_VFABI_DEMANGLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_XCODE_TOOLCHAIN_BUILD=OFF
			-DLLVM_TOOL_YAML2OBJ_BUILD=OFF

			-DLLVM_TOOL_LLVM_AR_BUILD=OFF
			-DLLVM_TOOL_LLVM_AS_BUILD=OFF
			-DLLVM_TOOL_LLVM_AS_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_BCANALYZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_CAT_BUILD=OFF
			-DLLVM_TOOL_LLVM_CFI_VERIFY_BUILD=OFF
			-DLLVM_TOOL_LLVM_CGDATA_BUILD=OFF
			-DLLVM_TOOL_LLVM_CONFIG_BUILD=OFF
			-DLLVM_TOOL_LLVM_COV_BUILD=OFF
			-DLLVM_TOOL_LLVM_C_TEST_BUILD=OFF
			-DLLVM_TOOL_LLVM_CTXPROF_UTIL_BUILD=OFF
			-DLLVM_TOOL_LLVM_CVTRES_BUILD=OFF
			-DLLVM_TOOL_LLVM_CXXDUMP_BUILD=OFF
			-DLLVM_TOOL_LLVM_CXXFILT_BUILD=OFF
			-DLLVM_TOOL_LLVM_CXXMAP_BUILD=OFF
			-DLLVM_TOOL_LLVM_DEBUGINFO_ANALYZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_DEBUGINFOD_BUILD=OFF
			-DLLVM_TOOL_LLVM_DEBUGINFOD_FIND_BUILD=OFF
			-DLLVM_TOOL_LLVM_DIFF_BUILD=OFF
			-DLLVM_TOOL_LLVM_DIS_BUILD=OFF
			-DLLVM_TOOL_LLVM_DIS_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_DLANG_DEMANGLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_DRIVER_BUILD=OFF
			-DLLVM_TOOL_LLVM_DWARFDUMP_BUILD=OFF
			-DLLVM_TOOL_LLVM_DWARFUTIL_BUILD=OFF
			-DLLVM_TOOL_LLVM_DWP_BUILD=OFF
			-DLLVM_TOOL_LLVM_EXEGESIS_BUILD=OFF
			-DLLVM_TOOL_LLVM_EXTRACT_BUILD=OFF
			-DLLVM_TOOL_LLVM_GSYMUTIL_BUILD=OFF
			-DLLVM_TOOL_LLVM_IFS_BUILD=OFF
			-DLLVM_TOOL_LLVM_ISEL_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_ITANIUM_DEMANGLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_JITLINK_BUILD=OFF
			-DLLVM_TOOL_LLVM_JITLISTENER_BUILD=OFF
			-DLLVM_TOOL_LLVM_LIBTOOL_DARWIN_BUILD=OFF
			-DLLVM_TOOL_LLVM_LINK_BUILD=OFF
			-DLLVM_TOOL_LLVM_LIPO_BUILD=OFF
			-DLLVM_TOOL_LLVM_LTO2_BUILD=OFF
			-DLLVM_TOOL_LLVM_LTO_BUILD=OFF
			-DLLVM_TOOL_LLVM_MCA_BUILD=OFF
			-DLLVM_TOOL_LLVM_MC_ASSEMBLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_MC_BUILD=OFF
			-DLLVM_TOOL_LLVM_MC_DISASSEMBLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_MICROSOFT_DEMANGLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_ML_BUILD=OFF
			-DLLVM_TOOL_LLVM_MODEXTRACT_BUILD=OFF
			-DLLVM_TOOL_LLVM_MT_BUILD=OFF
			-DLLVM_TOOL_LLVM_NM_BUILD=OFF
			-DLLVM_TOOL_LLVM_OBJCOPY_BUILD=OFF
			-DLLVM_TOOL_LLVM_OBJDUMP_BUILD=OFF
			-DLLVM_TOOL_LLVM_OPT_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_OPT_REPORT_BUILD=OFF
			-DLLVM_TOOL_LLVM_PDBUTIL_BUILD=OFF
			-DLLVM_TOOL_LLVM_PROFDATA_BUILD=OFF
			-DLLVM_TOOL_LLVM_PROFGEN_BUILD=OFF
			-DLLVM_TOOL_LLVM_RC_BUILD=OFF
			-DLLVM_TOOL_LLVM_READOBJ_BUILD=OFF
			-DLLVM_TOOL_LLVM_READTAPI_BUILD=OFF
			-DLLVM_TOOL_LLVM_REDUCE_BUILD=OFF
			-DLLVM_TOOL_LLVM_REMARKUTIL_BUILD=OFF
			-DLLVM_TOOL_LLVM_RTDYLD_BUILD=OFF
			-DLLVM_TOOL_LLVM_RUST_DEMANGLE_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_SHLIB_BUILD=OFF
			-DLLVM_TOOL_LLVM_SIM_BUILD=OFF
			-DLLVM_TOOL_LLVM_SIZE_BUILD=OFF
			-DLLVM_TOOL_LLVM_SPECIAL_CASE_LIST_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_SPLIT_BUILD=OFF
			-DLLVM_TOOL_LLVM_STRESS_BUILD=OFF
			-DLLVM_TOOL_LLVM_STRINGS_BUILD=OFF
			-DLLVM_TOOL_LLVM_SYMBOLIZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_TLI_CHECKER_BUILD=OFF
			-DLLVM_TOOL_LLVM_UNDNAME_BUILD=OFF
			-DLLVM_TOOL_LLVM_XRAY_BUILD=OFF
			-DLLVM_TOOL_LLVM_YAML_NUMERIC_PARSER_FUZZER_BUILD=OFF
			-DLLVM_TOOL_LLVM_YAML_PARSER_FUZZER_BUILD=OFF
		BUILD_COMMAND
			${CMAKE_COMMAND} -E env ${BUILD_ENV}
				${CMAKE_COMMAND} --build .
		INSTALL_COMMAND ${CMAKE_COMMAND} --install . --strip
	)

	add_dependencies(clang clang-binaries)

	set(clangToolNames
		clang
		clang++
	)

	RenameBinaryAliases(clang "${clangToolNames}")
	AddBinaryAliases(clang "${clangToolNames}")

	set(clangUselessFiles
		"bin/clang-cl${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/hmaptool"
		"lib/cmake/llvm/LLVMConfigExtensions.cmake"
	)

	DeleteUselessFiles(clang "${clangUselessFiles}")
endif()

if (BUILD_BINUTILS)
	list(APPEND BINUTILS_C_FLAGS ${EP_C_FLAGS})
	list(APPEND BINUTILS_EXE_LINKER_FLAGS ${EP_EXE_LINKER_FLAGS})

	EnableConfigureLTO("BINUTILS")

	ListToString("BINUTILS_C_FLAGS")
	ListToString("BINUTILS_EXE_LINKER_FLAGS")

	AddCompilerConfigureEnv("BINUTILS" "C")

	list(APPEND BINUTILS_ENV ${CONFIGURE_ENV} ${BUILD_ENV})

	AddTargetConfigureArgs("BINUTILS")

	list(APPEND BINUTILS_ARGS ${CONFIGURE_ARGS})

	ExternalProject_Add(binutils-binaries
		${EP_OPTIONS_BINUTILS}
		CONFIGURE_COMMAND
			"${SOURCE_DIR_BINUTILS}/configure"
				${BINUTILS_ENV}
				${BINUTILS_ARGS}
				--disable-gdb
				--disable-gold
				--disable-plugins
				--disable-sim
				--without-zlib
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

	set(binutilsToolNames
		ar
		as
		ld
		nm
		ranlib
		strip
	)

	set(binutilsDirectoryToolNames
		ar
		as
		ld
		nm
		ranlib
		strip
	)

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

	set(binutilsUselessFiles
		"bin/x86_64-nacl-addr2line${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-c++filt${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-elfedit${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-gprof${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-ld.bfd${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-objcopy${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-size${CMAKE_EXECUTABLE_SUFFIX}"
		"bin/x86_64-nacl-strings${CMAKE_EXECUTABLE_SUFFIX}"
		"share/info/as.info"
		"share/info/bfd.info"
		"share/info/binutils.info"
		"share/info/configure.info"
		"share/info/dir"
		"share/info/gprof.info"
		"share/info/ld.info"
		"share/info/standards.info"
		"share/man/man1/x86_64-nacl-addr2line.1"
		"share/man/man1/x86_64-nacl-ar.1"
		"share/man/man1/x86_64-nacl-as.1"
		"share/man/man1/x86_64-nacl-c++filt.1"
		"share/man/man1/x86_64-nacl-dlltool.1"
		"share/man/man1/x86_64-nacl-elfedit.1"
		"share/man/man1/x86_64-nacl-gprof.1"
		"share/man/man1/x86_64-nacl-ld.1"
		"share/man/man1/x86_64-nacl-nlmconv.1"
		"share/man/man1/x86_64-nacl-nm.1"
		"share/man/man1/x86_64-nacl-objcopy.1"
		"share/man/man1/x86_64-nacl-objdump.1"
		"share/man/man1/x86_64-nacl-ranlib.1"
		"share/man/man1/x86_64-nacl-readelf.1"
		"share/man/man1/x86_64-nacl-size.1"
		"share/man/man1/x86_64-nacl-strings.1"
		"share/man/man1/x86_64-nacl-strip.1"
		"share/man/man1/x86_64-nacl-windmc.1"
		"share/man/man1/x86_64-nacl-windres.1"
		"x86_64-nacl/bin/ld.bfd${CMAKE_EXECUTABLE_SUFFIX}"
		"x86_64-nacl/bin/objcopy${CMAKE_EXECUTABLE_SUFFIX}"
		"x86_64-nacl/bin/objdump${CMAKE_EXECUTABLE_SUFFIX}"
	)

	DeleteUselessFiles(binutils "${binutilsUselessFiles}")
endif()

if (BUILD_NACL)
	option(BUILD_NACL_INCLUDE "Build the nacl include." ON)
endif()

if (BUILD_NACL AND BUILD_NACL_INCLUDE)
	set(src_include "${SOURCE_DIR_NACL}/src/include/nacl")
	set(amd64_include "${CMAKE_INSTALL_PREFIX}/x86_64-nacl/include/nacl")
	set(arm_include "${CMAKE_INSTALL_PREFIX}/arm-nacl/include/nacl")

	set(include_file_list
		nacl_exception.h
		nacl_minidump.h
		simd.h
	)

	list(APPEND include_command ${CMAKE_COMMAND} -E make_directory "${amd64_include}")

	foreach(include_file IN LISTS include_file_list)
		list(APPEND include_command
			 && ${CMAKE_COMMAND} -E copy_if_different
				"${src_include}/${include_file}" "${amd64_include}/${include_file}"
		)
	endforeach()

	ExternalProject_Add(nacl-include
		${EP_OPTIONS_NACL}
		CONFIGURE_COMMAND echo
		BUILD_COMMAND echo
		INSTALL_COMMAND ${include_command}
	)
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

# This intentionally do not delete `${CMAKE_INSTALL_PREFIX}` but the
# unmodified `${CMAKE_CURRENT_BINARY_DIR}/install` default value we set
# ourselves, and will then fail to delete the directory when customized,
# just in case someone does: `cmake -DCMAKE_INSTALL_PREFIX=/usr`…
add_custom_target(distclean
    COMMAND
		${CMAKE_COMMAND} -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/install"
		&& ${CMAKE_COMMAND} --build "${CMAKE_CURRENT_BINARY_DIR}" --target clean
)
