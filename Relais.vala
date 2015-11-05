/*
 * Copyright (c) 2011-2015 THOMAS-Projekt (https://thomas-projekt.de)
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

public class THOMAS.Relais : SerialDevice {
    private static const uint BAUDRATE = Posix.B19200;

    public Relais (string tty_name) {
        base (tty_name, BAUDRATE);
        base.attach ((termios) => {
            /* Programm soll auf Antwort des Relais warten */
            termios.c_cc[Posix.VMIN] = 0;
            termios.c_cc[Posix.VTIME] = 1;

            /* Schnittstelle konfigurieren */
            termios.c_cflag &= ~Posix.PARENB; /* kein Partybit */
            termios.c_cflag &= ~Posix.CSTOPB; /* 1 Stopbit */
            termios.c_cflag &= ~Posix.CSIZE; /* 8 Datenbits */
            termios.c_cflag |= Posix.CS8;
            termios.c_cflag |= (Posix.CLOCAL | Posix.CREAD);

            termios.c_lflag &= ~(Posix.ICANON | Posix.ECHO | Posix.ECHOE | Posix.ISIG);
            termios.c_oflag &= ~Posix.OPOST; /* "raw" Input */

            /* Neue Konfiguration zurückgeben */
            return termios;
        });
    }

    public void setup () {
        /* Initalisierung */
        if (!send_with_checksum ({ 1, 1, 0 })) {
            warning ("Die Relaiskarte wurde möglicherweise nicht korrekt initialisiert.");
        }

        debug ("Die Relaiskarte wurde erfolgreich initialisiert");
    }

    public void set_relay (int port, bool state) {
        uint8 val = 0;
        uint8 rval = 0;

        if (state) {
            val = 1 << (port - 1);
            rval = rval | val;
        } else {
            val = ~(1 << (port - 1));
            rval = rval & val;
        }

        if (!send_with_checksum ({ 3, 1, rval })) {
            warning ("Das Relay wurde möglicherweise nicht korrekt geschaltet.");
        }
    }

    public void set_all (bool state) {
        if (!send_with_checksum ({ 3, 1, state ? 255 : 0 })) {
            warning ("Die Relais wurdne möglicherweise nicht korrekt geschaltet.");
        }
    }

    private bool send_with_checksum (uint8[] data) {
        /* Befehl senden */
        base.send_package ({ data[0], data[1], data[2], data[0] ^ data[1] ^ data[2] }, false);

        /*
         * FIXME: Überprüfung der Antwort liefert unschlüssige oder garkeine Werte, Relais schalten dennoch.
         * uint8[] receive = base.read_package (false, 4, false);
         * return ((receive[0] ^ receive[1] ^ receive[2]) == receive[3]);
         */

        return true;
    }
}