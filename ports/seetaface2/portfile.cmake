include(vcpkg_common_functions)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO seetafaceengine/SeetaFace2
    REF a587833fef746e4dbc850f4bd0c62c1b5e7e2b52
    SHA512 32552257ddeae7b444d7db461c6705351e6f7384cde9b3e3cc963e8efd918577393933d1635a838dd3d0e46f381c853898414f470817a60f4995df157b5a37d7
    HEAD_REF master
    PATCHES fix_dllimport.patch
)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA
    OPTIONS -DBUILD_EXAMPLE=OFF -DCMAKE_DEBUG_POSTFIX=
)

vcpkg_install_cmake()

vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake)

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)

file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/seetaface2 RENAME copyright)

vcpkg_copy_pdbs()
