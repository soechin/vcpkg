# Automatically generated by scripts/boost/generate-ports.ps1

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO boostorg/tti
    REF boost-1.80.0
    SHA512 bde1c576d526a9eb51419371b05bc3104de8458b5d4ecf4fdd8fd6d79af4e31f79a6e09fedd6515930098664a254d0f34ae1c506bb8be88dcd038355e7f8c3e4
    HEAD_REF master
)

include(${CURRENT_INSTALLED_DIR}/share/boost-vcpkg-helpers/boost-modular-headers.cmake)
boost_modular_headers(SOURCE_PATH ${SOURCE_PATH})
