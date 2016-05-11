# THOMAS-Vala
Vala-Implementierung des Servers

## Abhängigkeiten
`sudo apt-get install valac-0.30 cmake libgee-0.8-dev libnm-glib-dev libopencv-dev libgtop2-dev libavahi-gobject-dev libavahi-client-dev libsoup2.4-dev libjson-glib-dev`

## Kompatibilität mit Ubuntu 14.04
### Valac 0.30 installieren
```
sudo add-apt-repository ppa:vala-team/ppa
sudo apt-get update
sudo apt-get install valac-0.30
```

### Libsoup 2.52 installieren
```
sudo apt-get install libgirepository1.0-dev intltool
wget http://archive.ubuntu.com/ubuntu/pool/main/libs/libsoup2.4/libsoup2.4_2.52.2.orig.tar.xz
tar xf libsoup2.4_2.52.2.orig.tar.xz
cd libsoup-2.52.2
./configure --prefi=/usr
make
sudo make install
```

## Server kompilieren
```
mkdir build
cd build
cmake ..
make
```

## Network Manager einrichten:
´´`
nmcli device wifi connect SSID password 'coolesPassword'
```

## Hilfe
```
Usage:
  thomas [OPTION...] Server starten

Help Options:
  -h, --help                            Show help options

Application Options:
  -d, --debug                           Aktiviert den Debugmodus
  -A, --arduino-tty=PORT/NONE           Port des Arduinos
  -M, --motor-tty=PORT/NONE             Port der Motorsteuerung
  -R, --relais-tty=PORT/NONE            Port der Relaiskarte
  -C, --camera=ID/-1                    ID der Kamera
  -N, --network-interface=INTERFACE     Das fuer Statistiken zu benutzende Netzwerkinterface
  -n, --no-network-manager              Nicht mit dem Network-Manager verbinden
  -W, --webserver-port=PORT             Port des Webservers
  -m, --enable-minimalmode              Aktiviert den Minimalmodus des Arduinos
  -H, --html-directory=PFAD             Pfad zum HTML-Verzeichnis
```
