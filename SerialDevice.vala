/*
 * Copyright (c) 2011-2015 THOMAS Developers (https://thomas-projekt.de)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

public abstract class THOMAS.SerialDevice : Object {
    private int handle;

    protected SerialDevice (string tty_name, Posix.speed_t baudrate) {
        /* Handle erstellen */
        handle = Posix.open (tty_name, Posix.O_RDWR | Posix.O_NOCTTY | Posix.LOG_NDELAY);

        if (handle == -1) {
            error ("Öffnen von %s fehlgeschlagen.", tty_name);
        }

        Posix.termios termios;

        /* Attribute abrufen */
        if (Posix.tcgetattr (handle, out termios) != 0) {
            error ("Speichern der TTY-Attribute fehlgeschlagen.");
        }

        /* Baudrate setzen */
        termios.c_ispeed = baudrate;
        termios.c_ospeed = baudrate;

        /* Programm soll auf Antwort des Arduinos warten */
        termios.c_cc[Posix.VMIN] = 1;
        termios.c_cc[Posix.VTIME] = 1;

        /* Schnittstelle konfigurieren */
        termios.c_cflag |= Posix.CS8;
        termios.c_iflag &= ~(Posix.IGNBRK | Posix.BRKINT | Posix.ICRNL | Posix.IXON);
        termios.c_oflag &= ~(Posix.OPOST | Posix.ONLCR);
        termios.c_lflag &= ~(Posix.ECHO | Linux.Termios.ECHOCTL | Posix.ICANON | Posix.ISIG | Posix.IEXTEN);

        /* Neue Konfiguration übernehmen */
        if (Posix.tcsetattr (handle, Posix.TCSAFLUSH, termios) != 0) {
            error ("Setzen von TTY-Attributen fehlgeschlagen.");
        }

        debug ("Schnittstelle %s initialisiert.", tty_name);
    }

    protected void send_package (uint8[] package, bool send_header = true) {
        if (package.length > uint8.MAX) {
            error ("Paket zu groß.");
        }

        uint8 package_length = (uint8)package.length;
        uint8[] data = {};

        if (send_header) {
            data += package_length;

            for (int i = 0; i < package_length; i++) {
                data += package[i];
            }
        } else {
            data = package;
        }

        if (Posix.write (handle, data, data.length) != data.length) {
            error ("Senden des Paketes fehlgeschlagen.");
        }
    }

    protected uint8[] read_package () {
        uint8[] header = new uint8[1];

        if (Posix.read (handle, header, 1) != 1) {
            error ("Lesen des Paketheaders fehlgeschlagen.");
        }

        uint8 package_length = header[0];

        uint8[] package = {};

        uint8[] temp_buffer = new uint8[1];

        for (int i = 0; i < package_length; i++) {
            if (Posix.read (handle, temp_buffer, 1) != 1) {
                error ("Fehler beim Lesen des Paketes");
            }

            package += temp_buffer[0];
        }

        return package;
    }
}