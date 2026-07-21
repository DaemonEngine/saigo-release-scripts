macro(FindTool SLUG FILE NAME ENABLEMENT)
	set("DEFAULT_${SLUG}" "${ENABLEMENT}")

	find_program(PATH_${SLUG} NAMES "${FILE}")

	if (NOT PATH_${SLUG})
		set("DEFAULT_${SLUG}" OFF)
	endif()

	option("USE_${SLUG}" "Enable ${NAME} when possible." "${DEFAULT_${SLUG}}")

	if (PATH_${SLUG})
		if (USE_${SLUG})
			message(STATUS "${NAME} available and used")
		else()
			message(STATUS "${NAME} available but not used")
		endif()
	else()
		message(STATUS "${NAME} not available")
	endif()
endmacro()

macro(ListToString NAME)
	list(JOIN ${NAME} " " ${NAME}_STRING)
endmacro()

macro(AddGitProject NAME DIR URL TAG)
	string(TOUPPER "${NAME}" SLUG)
	string(REPLACE "-" "_" SLUG "${SLUG}")
	set(GIT_REPOSITORY_${SLUG} "${URL}" CACHE STRING "${NAME} git repository location.")
	mark_as_advanced(GIT_REPOSITORY_${SLUG})

	set(REPOSITORY_DIR_${SLUG} "${DIR}")
	set(REPOSITORY_TAG_${SLUG} "${TAG}")

	if (CLONE_SHARED_REPOSITORIES)
		option(CLONE_${SLUG} "Clone the ${NAME} repository." ON)

		if (CLONE_${SLUG})
			set(patch_list "${ARGN}")

			if (patch_list)
				list(APPEND PATCH_${SLUG}
					git reset --hard "${REPOSITORY_TAG_${SLUG}}")

				foreach(patch_file IN LISTS patch_list)
					list(APPEND PATCH_${SLUG}
						&& git am "${CMAKE_SOURCE_DIR}/patches/${DIR}/${patch_file}")
				endforeach()

				list(APPEND PATCH_${SLUG}
					&& git rebase --committer-date-is-author-date "${REPOSITORY_TAG_${SLUG}}")
			else()
				set(PATCH_${SLUG} echo)
			endif()

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

		if (BUILD_${SLUG})
			add_custom_target("${NAME}" ALL)
		endif()
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

macro(AddTarProject PARENT_NAME NAME SUBDIR URL)
	string(TOUPPER "${PARENT_NAME}" PARENT_SLUG)
	string(TOUPPER "${NAME}" SLUG)
	set(TARGET_SLUG "${PARENT_SLUG}_${SLUG}")
	set(TARGET_NAME "${PARENT_NAME}-${NAME}")

	if (NOT DEFINED BUILD_${PARENT_SLUG})
		option(BUILD_${PARENT_SLUG} "Build the ${PARENT_NAME}." "${DEFAULT_BUILD}")
	endif()

	if (BUILD_${PARENT_SLUG})
		if (NOT TARGET "${PARENT_NAME}")
			add_custom_target("${PARENT_NAME}" ALL)
		endif()
	endif()

	set(DIR "${TARGET_NAME}")
	set(SUBDIR_${TARGET_SLUG} "${SUBDIR}")

	set(TARBALL_${TARGET_SLUG} ${URL} CACHE STRING "${TARGET_NAME} repository.")
	mark_as_advanced(TARBALL_${TARGET_SLUG})

	if (SHARED_REPOSITORIES_DIR)
		set(SOURCE_DIR_${TARGET_SLUG} "${SHARED_REPOSITORIES_DIR}/${DIR}")
	else()
		set(SOURCE_DIR_${TARGET_SLUG} "${EXTERNAL_PROJECT_SOURCES_DIR}/${DIR}")
	endif()

	if (CLONE_SHARED_REPOSITORIES)
		option(CLONE_${TARGET_SLUG} "Clone the ${TARGET_NAME}." ON)

		if (CLONE_${TARGET_SLUG})
			ExternalProject_Add("${TARGET_NAME}-directory"
				URL "${URL}"
				SOURCE_DIR "${SOURCE_DIR_${TARGET_SLUG}}"
				CONFIGURE_COMMAND echo
				BUILD_COMMAND echo
				INSTALL_COMMAND echo
				DOWNLOAD_EXTRACT_TIMESTAMP ON
			)
		endif()
	else()
		option(BUILD_${TARGET_SLUG} "Build the ${TARGET_NAME}." ON)
	endif()

	if (SHARED_REPOSITORIES_DIR)
		set(SOURCE_DIR_${TARGET_SLUG} ${SHARED_REPOSITORIES_DIR}/${DIR})

		set(EP_OPTIONS_${TARGET_SLUG}
			SOURCE_DIR "${SOURCE_DIR_${TARGET_SLUG}}"
		)
	else()
		set(EP_SOURCE_DIR_${TARGET_SLUG} ${EXTERNAL_PROJECT_SOURCES_DIR}/${DIR})
		set(SOURCE_DIR_${TARGET_SLUG} "${CMAKE_BINARY_DIR}/${EP_SOURCE_DIR_${SLUG}}")

		set(EP_OPTIONS_${TARGET_SLUG}
			SOURCE_DIR "${EP_SOURCE_DIR_${TARGET_SLUG}}"
			URL "${URL}"
		)
	endif()

	if (BUILD_${PARENT_SLUG} AND BUILD_${TARGET_SLUG})
		ExternalProject_Add("${TARGET_NAME}-binaries"
			${EP_OPTIONS_${TARGET_SLUG}}
			CONFIGURE_COMMAND echo
			BUILD_COMMAND echo
			INSTALL_COMMAND
				mkdir -p "${CMAKE_INSTALL_PREFIX}/${SUBDIR_${TARGET_SLUG}}"
				&& rsync -av
					"${SOURCE_DIR_${TARGET_SLUG}}/."
					"${CMAKE_INSTALL_PREFIX}/${SUBDIR_${TARGET_SLUG}}/."
			DOWNLOAD_EXTRACT_TIMESTAMP ON
		)

		add_dependencies(${PARENT_NAME} ${TARGET_NAME}-binaries)
	endif()
endmacro()

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
		set(aliasFile "${REFERENCE_ARCH_NAME}-${REFERENCE_SYSTEM_NAME}-${toolName}")
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
			set(referenceName "${REFERENCE_ARCH_NAME}-${REFERENCE_SYSTEM_NAME}-${toolName}${CMAKE_EXECUTABLE_SUFFIX}")
			set(aliasFile "${archName}-${REFERENCE_SYSTEM_NAME}-${toolName}")
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

	set(referenceName "${REFERENCE_ARCH_NAME}-${REFERENCE_SYSTEM_NAME}")

	foreach(archName ${ALIAS_DIR_ARCH_NAMES})
		set(aliasDir "${archName}-${REFERENCE_SYSTEM_NAME}")
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

function(DeleteUselessFiles targetName filePaths)
	list(APPEND deleteCommand "echo")

	foreach(filePath IN LISTS filePaths)
		list(APPEND deleteCommand
			&& ${CMAKE_COMMAND} -E rm -f "${CMAKE_INSTALL_PREFIX}/${filePath}"
		)
	endforeach()

	set(deletesName ${targetName}-deletes)

	add_custom_target(${deletesName}
		ALL
		COMMAND ${deleteCommand}
		DEPENDS ${targetName}-binaries
	)

	add_dependencies(${targetName} ${deletesName})
endfunction()

macro(AddCompilerFlags NAME LANGS)
	foreach(LANG IN ITEMS ${LANGS})
		foreach(FLAG IN ITEMS ${ARGN})
			string(TOUPPER "FLAG_${FLAG}" FLAG_SLUG)
			string(REGEX REPLACE "[^A-Z0-9]" "_" FLAG_SLUG "${FLAG_SLUG}")
			string(REGEX REPLACE "_+" "_" FLAG_SLUG "${FLAG_SLUG}")

			if ("${${FLAG_SLUG}}" STREQUAL "")
				check_compiler_flag("${LANG}" "${FLAG}" ${FLAG_SLUG})
			endif()

			if (${FLAG_SLUG})
				list(APPEND ${NAME}_${LANG}_FLAGS "${FLAG}")
			endif()
		endforeach()
	endforeach()
endmacro()

macro(AddCompilerDefinitions NAME)
	foreach(FLAG IN ITEMS ${ARGN})
		list(APPEND ${NAME}_DEFINITIONS ${FLAG})
	endforeach()
endmacro()

macro(AddConfigureEnv NAME)
	foreach(VAR IN ITEMS ${ARGN})
		list(APPEND ${NAME}_ENV "${VAR}")
	endforeach()
endmacro()

macro(AddToolConfigureEnv NAME VALUE)
	AddConfigureEnv("CONFIGURE" "${NAME}=${VALUE}")
endmacro()

macro(AddTripleToolConfigureEnv NAME PATH)
	find_program(PATH_TRIPLE_${NAME} NAMES "${TRIPLE_HOST}-${PATH}")

	if (PATH_TRIPLE_${NAME})
		set(TRIPLE_${NAME} "${PATH_TRIPLE_${NAME}}")
	else()
		set(TRIPLE_${NAME} "${PATH}")
	endif()

	AddToolConfigureEnv("${NAME}" "${TRIPLE_${NAME}}")
endmacro()

macro(EnableConfigureLTO NAME)
	if (USE_LTO)
		list(APPEND ${NAME}_C_FLAGS ${LTO_FLAGS})

		if (YOKAI_C_COMPILER_MINGW)
			AddCompilerDefinitions("${NAME}" "-Dffs=__builtin_ffs")
		endif()

		list(APPEND ${NAME}_EXE_LINKER_FLAGS ${${NAME}_CFLAGS})
	endif()
endmacro()

macro(AddCompilerConfigureEnv NAME LANGS)
	ListToString("${NAME}_DEFINITIONS")

	foreach(LANG IN ITEMS ${LANGS})
		list(APPEND ${NAME}_${LANG}_FLAGS ${${NAME}_DEFINITIONS})

		ListToString("${NAME}_${LANG}_FLAGS")

		AddConfigureEnv("${NAME}" "CFLAGS=${${NAME}_${LANG}_FLAGS_STRING}")
	endforeach()

	ListToString("${NAME}_EXE_LINKER_FLAGS")

	AddConfigureEnv("${NAME}" "LDFLAGS=${${NAME}_EXE_LINKER_FLAGS_STRING}")
endmacro()
