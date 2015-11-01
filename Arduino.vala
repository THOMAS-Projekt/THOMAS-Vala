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

public class THOMAS.Arduino : SerialDevice {
    public enum MessagePriority {
        INFO,
        WARNING,
        ERROR
    }

    private Mutex mutex = Mutex ();

    private bool minimalmode_enabled = false;

    public Arduino (string tty_name) {
        base (tty_name, 9600);
    }

    public void wait_for_initialisation () {
        while (base.read_package ()[0] != 0) {
        }
    }

    public void setup (bool minimalmode_enabled) {
        /* Heartbeat-Thread */
        new Thread<int> (null, () => {
            while (true) {
                mutex.@lock ();

                /* Heartbeat senden */
                base.send_package ({ 0 });

                if (base.read_package ()[0] != 1) {
                    error ("Fehler beim Empfangen der Heartbeat Antwort");
                }

                mutex.unlock ();
                /* Eine Sekunde warten */
                Thread.usleep (1000 * 1000);
            }
        });

        new Thread<int> (null, update_wifi_information);

        if (!minimalmode_enabled) {
            new Thread<int> (null, () => {
                while (true) {
                    /* TODO: Könnte man implementieren, wenn man Lust hätte! */
                    get_usensor_distance ();
                }
            });
        } else {
            enable_minimalmode ();
        }
    }

    /* TODO: Rückgabe prüfen */
    public void print_message (MessagePriority priority, string message) {
        uint8[] package = {};
        package += 1;
        package += (uint8)priority;
        package += (uint8)message.data.length;

        for (int i = 0; i < message.data.length; i++) {
            package += message.data[i];
        }

        mutex.@lock ();

        base.send_package (package);

        if (base.read_package ()[0] != message.data.length) {
            error ("Der Rückgabetext stimmt nicht mit dem gesendeten Text überein!");
        }

        mutex.unlock ();
    }

    public void enable_minimalmode () {
        mutex.@lock ();

        base.send_package ({ 5, 1 });

        if (base.read_package ()[0] != 1) {
            error ("Fehler beim aktivieren des Minimalmodus");
        }

        mutex.unlock ();

        minimalmode_enabled = true;

        debug ("Minimalmodus aktiviert");
    }

    public List<int> get_usensor_distance () {
        if (minimalmode_enabled) {
            error ("Es können keine USensor Daten im Minimalmodus abgerufen werden");
        }

        List<uint8> distances = new List<uint8> ();

        mutex.@lock ();

        base.send_package ({ 2, 0, 0 });

        uint8[] data = base.read_package ();

        mutex.unlock ();

        for (int i = 0; i < data.length; i++) {
            distances.append (data[i] * 2);
        }

        return distances;
    }

    public int update_wifi_information () {
        while (true) {
            /* Update SSID */
            {
                string ssid = "LOL!";

                uint8[] package = { 4, 0, (uint8)ssid.data.length };

                for (int i = 0; i < ssid.data.length; i++) {
                    package += ssid.data[i];
                }

                mutex.@lock ();

                /* SSID Updaten */
                base.send_package (package);

                if (base.read_package ()[0] != 1) {
                    error ("Fehler beim Senden der SSID");
                }

                mutex.unlock ();
            }

            /* Update Signalstrength */
            {
                int signal_strength = 40;

                mutex.@lock ();
                base.send_package ({ 4, 1, (uint8)signal_strength });

                if (base.read_package ()[0] != 1) {
                    error ("Fehler beim Senden der Signalstrength");
                }

                mutex.unlock ();
            }

            Thread.usleep (3000 * 1000);
        }
    }
}