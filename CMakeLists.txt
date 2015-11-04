# Projektname
project (thomas)

# Anforderungen ans Buildsystem
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

# Global configuration
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (RELEASE_NAME "${CMAKE_PROJECT_NAME}")
set (VERSION "0.1")
set (VERSION_INFO "Release")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

# CMake-Dateien
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Auf Vala überprüfen
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.18" MINIMUM)
include (ValaPrecompile)

# C-Compiler Warnungen ausblenden
add_definitions (-w)

# Auf Abhängigkeiten prüfen
find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED gthread-2.0 gio-2.0 gee-0.8 libnm-glib opencv)

# Bibliotheken linken
add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

# Configure precompile
vala_precompile (VALA_C
    Main.vala
    Logger.vala
    NetworkManager.vala
    Arduino.vala
    SerialDevice.vala
    MotorControl.vala
    Relais.vala
    RemoteServer.vala
    UDPStreamer.vala
PACKAGES
    gio-2.0
    gee-0.8
    posix
    linux
    libnm-glib
    opencv
OPTIONS
    --vapidir=../vapi/
    --thread
    --target-glib 2.32
)

# Add executable
add_executable (${CMAKE_PROJECT_NAME} ${VALA_C})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION bin)