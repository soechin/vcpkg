# pdfium
set(PDFIUM_URL "https://pdfium.googlesource.com/pdfium.git")
set(PDFIUM_COMMIT "chromium/4240")
set(PDFIUM_PARENT "${CURRENT_BUILDTREES_DIR}/src")
set(PDFIUM_DIR "${CURRENT_BUILDTREES_DIR}/src/pdfium")

# depot_tools
set(DEPOT_URL "https://chromium.googlesource.com/chromium/tools/depot_tools.git")
set(DEPOT_COMMIT "master")
set(DEPOT_TOOLS "${CURRENT_BUILDTREES_DIR}/src/depot_tools")

# environment variables
set(ENV{DEPOT_TOOLS_WIN_TOOLCHAIN} "0")

# output directory
set(OUT_DEBUG_DIR "${CURRENT_BUILDTREES_DIR}/out/${TARGET_TRIPLET}-debug")
set(OUT_RELEASE_DIR "${CURRENT_BUILDTREES_DIR}/out/${TARGET_TRIPLET}-release")

# add git to path
vcpkg_find_acquire_program(GIT)
get_filename_component(GIT_DIR ${GIT} DIRECTORY)
vcpkg_add_to_path(${GIT_DIR})

# shells
if(CMAKE_HOST_WIN32)
    set(GCLIENT_SHELL "${DEPOT_TOOLS}/gclient.bat")
    set(GN_SHELL "${DEPOT_TOOLS}/gn.bat")
    set(NINJA_SHELL "${DEPOT_TOOLS}/ninja.exe")
else()
    set(GCLIENT_SHELL "${DEPOT_TOOLS}/gclient")
    set(GN_SHELL "${DEPOT_TOOLS}/gn")
    set(NINJA_SHELL "${DEPOT_TOOLS}/ninja")
endif()

# checkout function
function(git_checkout)
    set(options)
    set(oneValueArgs URL COMMIT DIRECTORY)
    set(multiValueArgs)
    cmake_parse_arguments(_checkout "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    vcpkg_find_acquire_program(GIT)

    if(NOT EXISTS ${_checkout_DIRECTORY})
        file(MAKE_DIRECTORY ${_checkout_DIRECTORY})

        vcpkg_execute_required_process(
            ALLOW_IN_DOWNLOAD_MODE
            COMMAND ${GIT} init
            WORKING_DIRECTORY ${_checkout_DIRECTORY}
            LOGNAME git-init-${TARGET_TRIPLET}
        )

        vcpkg_execute_required_process(
            ALLOW_IN_DOWNLOAD_MODE
            COMMAND ${GIT} remote add origin ${_checkout_URL}
            WORKING_DIRECTORY ${_checkout_DIRECTORY}
            LOGNAME git-remote-${TARGET_TRIPLET}
        )
    endif()

    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} fetch
        WORKING_DIRECTORY ${_checkout_DIRECTORY}
        LOGNAME git-fetch-${TARGET_TRIPLET}
    )

    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} checkout ${_checkout_COMMIT}
        WORKING_DIRECTORY ${_checkout_DIRECTORY}
        LOGNAME git-checkout-${TARGET_TRIPLET}
    )

    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} reset --hard
        WORKING_DIRECTORY ${_checkout_DIRECTORY}
        LOGNAME git-reset-${TARGET_TRIPLET}
    )
endfunction()

# checkout
message("checkout depot_tools")
git_checkout(
    URL ${DEPOT_URL}
    COMMIT ${DEPOT_COMMIT}
    DIRECTORY ${DEPOT_TOOLS}
)

message("checkout pdfium")
git_checkout(
    URL ${PDFIUM_URL}
    COMMIT ${PDFIUM_COMMIT}
    DIRECTORY ${PDFIUM_DIR}
)

# gclient
message("gclient config")
vcpkg_execute_required_process(
    ALLOW_IN_DOWNLOAD_MODE
    COMMAND ${GCLIENT_SHELL} config --verbose --unmanaged ${PDFIUM_URL}
    WORKING_DIRECTORY ${PDFIUM_PARENT}
    LOGNAME gclient-config-${TARGET_TRIPLET}
)

message("gclient sync")
vcpkg_execute_required_process(
    ALLOW_IN_DOWNLOAD_MODE
    COMMAND ${GCLIENT_SHELL} sync --verbose --force
    WORKING_DIRECTORY ${PDFIUM_PARENT}
    LOGNAME gclient-sync-${TARGET_TRIPLET}
)

# apply patches for windows
if(VCPKG_TARGET_IS_WINDOWS)
    # build shared library
    set(VCPKG_LIBRARY_LINKAGE "dynamic")

    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} apply -v "${CURRENT_PORT_DIR}/01-build_shared_library.patch"
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME git-apply-${TARGET_TRIPLET}
    )

    # fix error "could not find proper second linker member"
    set(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK enabled)

    # add rc resources
    file(COPY "${CURRENT_PORT_DIR}/resources.rc" DESTINATION ${PDFIUM_DIR})

    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} apply -v "${CURRENT_PORT_DIR}/02-add_rc_resources.patch"
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME git-apply-${TARGET_TRIPLET}
    )

    # fix rc compiler
    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} apply -v "${CURRENT_PORT_DIR}/03-fix_rc_compiler.patch"
        WORKING_DIRECTORY "${PDFIUM_DIR}/build"
        LOGNAME git-apply-${TARGET_TRIPLET}
    )

    # use stdcall
    vcpkg_execute_required_process(
        ALLOW_IN_DOWNLOAD_MODE
        COMMAND ${GIT} apply -v "${CURRENT_PORT_DIR}/04-use_stdcall.patch"
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME git-apply-${TARGET_TRIPLET}
    )
endif()

# debug
if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    file(MAKE_DIRECTORY ${OUT_DEBUG_DIR})

    file(COPY "${CURRENT_PORT_DIR}/args.gn" DESTINATION ${OUT_DEBUG_DIR})
    file(APPEND "${OUT_DEBUG_DIR}/args.gn" "\n")
    file(APPEND "${OUT_DEBUG_DIR}/args.gn" "is_debug = true\n")
    file(APPEND "${OUT_DEBUG_DIR}/args.gn" "symbol_level = 2\n")

    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        file(APPEND "${OUT_DEBUG_DIR}/args.gn" "target_cpu = \"x86\"\n")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        file(APPEND "${OUT_DEBUG_DIR}/args.gn" "target_cpu = \"x64\"\n")
    endif()

    message("gn generate debug")
    vcpkg_execute_required_process(
        COMMAND ${GN_SHELL} gen -v ${OUT_DEBUG_DIR}
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME gn-gen-${TARGET_TRIPLET}-debug
    )

    message("ninja compile debug")
    vcpkg_execute_required_process(
        COMMAND ${NINJA_SHELL} -v -C ${OUT_DEBUG_DIR}
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME ninja-c-${TARGET_TRIPLET}-debug
    )
endif()

# release
if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
    file(MAKE_DIRECTORY ${OUT_RELEASE_DIR})

    file(COPY "${CURRENT_PORT_DIR}/args.gn" DESTINATION ${OUT_RELEASE_DIR})
    file(APPEND "${OUT_RELEASE_DIR}/args.gn" "\n")
    file(APPEND "${OUT_RELEASE_DIR}/args.gn" "is_debug = false\n")
    file(APPEND "${OUT_RELEASE_DIR}/args.gn" "symbol_level = 0\n")

    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        file(APPEND "${OUT_RELEASE_DIR}/args.gn" "target_cpu = \"x86\"\n")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        file(APPEND "${OUT_RELEASE_DIR}/args.gn" "target_cpu = \"x64\"\n")
    endif()

    message("gn gen release")
    vcpkg_execute_required_process(
        COMMAND ${GN_SHELL} gen ${OUT_RELEASE_DIR}
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME gn-gen-${TARGET_TRIPLET}-release
    )

    message("ninja compile release")
    vcpkg_execute_required_process(
        COMMAND ${NINJA_SHELL} -C ${OUT_RELEASE_DIR}
        WORKING_DIRECTORY ${PDFIUM_DIR}
        LOGNAME ninja-c-${TARGET_TRIPLET}-release
    )
endif()

# install
message("install")
file(INSTALL "${PDFIUM_DIR}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/pdfium" RENAME copyright)

file(GLOB HEADER_FILES LIST_DIRECTORIES false "${PDFIUM_DIR}/public/*.h")
file(INSTALL ${HEADER_FILES} DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${OUT_DEBUG_DIR}/pdfium.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
file(INSTALL "${OUT_RELEASE_DIR}/pdfium.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")

file(INSTALL "${OUT_DEBUG_DIR}/pdfium.dll.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
file(INSTALL "${OUT_RELEASE_DIR}/pdfium.dll.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

file(INSTALL "${OUT_DEBUG_DIR}/pdfium.dll.pdb" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
file(INSTALL "${OUT_RELEASE_DIR}/pdfium.dll.pdb" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
