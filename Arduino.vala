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

    private NM.DeviceWifi? wifi_device = null;

    private NM.AccessPoint? active_accesspoint = null;

    public Arduino (string tty_name) {
        base (tty_name, 9600);
    }

    public void wait_for_initialisation () {
        while (base.read_package ()[0] != 0) {
        }
    }

    public void setup (bool minimalmode_enabled) {
        /* Heartbeat-Thread */
        Timeout.add (1000, () => {
            mutex.@lock ();

            /* Heartbeat senden */
            base.send_package ({ 0 });

            if (base.read_package ()[0] != 1) {
                error ("Fehler beim Empfangen der Heartbeat Antwort");
            }

            mutex.unlock ();

            return true;
        });

        if (!minimalmode_enabled) {
            Timeout.add (1000, () => {
                /* TODO: Könnte man implementieren, wenn man Lust hätte! */
                get_usensor_distance ();

                return true;
            });
        } else {
            enable_minimalmode ();
        }

        /* TODO: Evtl. ist es sinnvoll diese in den TCP Server zu implementieren und dann
         *  die entsprechenden Arduino Funktionen aufzurufen*/
        NM.Client nm_client = new NM.Client ();
        nm_client.get_devices ().@foreach ((device) => {
            if (device is NM.DeviceWifi) {
                wifi_device = (NM.DeviceWifi)device;
            }
        });

        if (wifi_device != null) {
            update_active_access_point ();
            wifi_device.notify["active-access-point"].connect (update_active_access_point);
        } else {
            warning ("Kein WLAN-Adapter gefunden!");
        }

        change_cam_position (0, -10);
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

    public int set_cam_position (uint8 camera, uint8 angle) {
        mutex.@lock ();

        base.send_package ({ 3, 0, camera, 0, angle });

        uint8 new_angle = base.read_package ()[0];

        mutex.unlock ();

        return new_angle;
    }

    public int change_cam_position (uint8 camera, int change_angle) {
        uint8 direction = change_angle < 0 ? 0 : 1;

        /*
         * TODO: Geht das auch schöner?! Auch das hierrüber
         * Wäre viel sinnvoller die Daten am Arduino in einen signed char zu ḱonvertieren,
         * sodass man die "direction" nicht angeben muss
         */
        if (direction == 0) {
            change_angle = change_angle * (-1);
        }

        change_angle = change_angle < 0 ? 0 : change_angle > 180 ? 180 : change_angle;

        mutex.@lock ();

        base.send_package ({ 3, 0, camera, 1, direction, (uint8)change_angle });

        uint8 new_angle = base.read_package ()[0];

        mutex.unlock ();

        return new_angle;
    }

    public void update_active_access_point () {
        active_accesspoint = wifi_device.get_active_access_point ();

        update_ssid_information ();

        update_signal_strength_information ();

        if (active_accesspoint != null) {
            active_accesspoint.notify["strength"].connect (update_signal_strength_information);
        }
    }

    public void update_ssid_information () {
        string ssid = active_accesspoint != null ? (string)active_accesspoint.get_ssid ().data : "No connection";

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

    public void update_signal_strength_information () {
        /* Update Signalstrength */
        uint8 signal_strength = active_accesspoint != null ? active_accesspoint.get_strength () : 0;

        mutex.@lock ();
        base.send_package ({ 4, 1, (uint8)signal_strength });

        if (base.read_package ()[0] != 1) {
            error ("Fehler beim Senden der Signalstrength");
        }

        mutex.unlock ();
    }
}