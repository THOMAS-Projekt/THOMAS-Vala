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

public class THOMAS.Arduino : SerialDevice {
    private static const uint BAUDRATE = 9600;

    public enum MessagePriority {
        INFO,
        WARNING,
        ERROR
    }

    public bool minimalmode_enabled { get; private set; }

    public Arduino (string tty_name, bool minimalmode_enabled) {
        base (tty_name, BAUDRATE);
        base.attach ((termios) => {
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

            /* Neue Konfiguration zurückgeben */
            return termios;
        });

        this.minimalmode_enabled = minimalmode_enabled;
    }

    public void wait_for_initialisation () {
        while (base.read_package ()[0] != 0) {
        }
    }

    public void setup () {
        /* Heartbeat-Timer */
        Timeout.add (1000, () => {
            /* Heartbeat senden */
            base.send_package ({ 0 });

            if (base.read_package ()[0] != 1) {
                error ("Fehler beim Empfangen der Heartbeat Antwort.");
            }

            return true;
        });

        if (minimalmode_enabled) {
            enable_minimalmode ();
        } else {
            Timeout.add (1000, () => {
                /* TODO: Könnte man implementieren, wenn man Lust hätte! */
                get_usensor_distances ();

                return true;
            });
        }
    }

    public void print_message (MessagePriority priority, string message) {
        uint8[] package = {};
        package += 1;
        package += (uint8)priority;
        package += (uint8)message.data.length;

        for (int i = 0; i < message.data.length; i++) {
            package += message.data[i];
        }

        base.send_package (package);

        if (base.read_package ()[0] != message.data.length) {
            error ("Der Rückgabetext stimmt nicht mit dem gesendeten Text überein!");
        }
    }

    public List<int> get_usensor_distances () {
        if (minimalmode_enabled) {
            error ("Es können keine USensor Daten im Minimalmodus abgerufen werden.");
        }

        base.send_package ({ 2, 0, 0 });

        List<uint8> distances = new List<uint8> ();
        uint8[] data = base.read_package ();

        for (int i = 0; i < data.length; i++) {
            distances.append (data[i] * 2);
        }

        return distances;
    }

    public int set_cam_position (uint8 camera, uint8 angle) {
        base.send_package ({ 3, 0, camera, 0, angle });

        return base.read_package ()[0];
    }

    public int change_cam_position (uint8 camera, int degree) {
        uint8 direction = (uint8)(degree >= 0);
        uint8 validated_degree = (uint8)degree.abs ().clamp (5, 180);

        base.send_package ({ 3, 0, camera, 1, direction, validated_degree });

        return base.read_package ()[0];
    }

    public void update_ssid (string ssid) {
        uint8[] package = { 4, 0, (uint8)ssid.data.length };

        for (int i = 0; i < ssid.data.length; i++) {
            package += ssid.data[i];
        }

        base.send_package (package);

        if (base.read_package ()[0] != 1) {
            error ("Fehler beim Setzen der SSID.");
        }
    }

    public void update_signal_strength (uint8 signal_strength) {
        base.send_package ({ 4, 1, signal_strength });

        if (base.read_package ()[0] != 1) {
            error ("Fehler beim Setzen der Signalstärke.");
        }
    }

    private void enable_minimalmode () {
        base.send_package ({ 5, 1 });

        if (base.read_package ()[0] != 1) {
            error ("Fehler beim Aktivieren des Minimalmodus.");
        }

        debug ("Minimalmodus aktiviert.");
    }
}