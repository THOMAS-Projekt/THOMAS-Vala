# Kompilieranweisungen
vala_precompile (VALA_C
    Main.vala
    Logger.vala
    NetworkManager.vala
    Arduino.vala
    SerialDevice.vala
    MotorControl.vala
    Relais.vala
    RemoteServer.vala
    ServiceProvider.vala
    Camera.vala
    UDPStreamer.vala
    SystemInformation.vala
    DistanceMap.vala
PACKAGES
    gio-2.0
    gee-0.8
    posix
    linux
    libnm-glib
    opencv
    gdk-pixbuf-2.0
    libgtop-2.0
    avahi-gobject
    avahi-client
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --thread
    --target-glib=2.32
)

# C-Compiler Warnungen ausblenden
add_definitions (-w)

# Ausführbare Datei hinzufügen
add_executable (${CMAKE_PROJECT_NAME} ${VALA_C})

# Installation
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION bin)