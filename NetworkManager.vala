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

public class THOMAS.NetworkManager : NM.Client {
    public signal void ssid_changed (string? ssid);
    public signal void signal_strength_changed (uint8 signal_strength);

    private NM.DeviceWifi? wifi_device = null;
    private NM.AccessPoint? active_access_point = null;

    public NetworkManager () {
        debug ("Suche nach WLAN-Adaptern...");

        /* WLAN-Adapter einlesen */
        base.get_devices ().@foreach ((device) => {
            if (device is NM.DeviceWifi) {
                /* TODO: Evtl. Anpassen, falls jemand auf die Idee kommt zwei WLAN-Adapter anzuschließen */
                wifi_device = (NM.DeviceWifi)device;
            }
        });

        if (wifi_device != null) {
            debug ("WLAN-Adapter %s gefunden.", wifi_device.get_hw_address ());

            update_active_access_point ();
            wifi_device.notify["active-access-point"].connect (update_active_access_point);
        } else {
            warning ("Keinen WLAN-Adapter gefunden!");
        }
    }

    private void update_active_access_point () {
        active_access_point = wifi_device.get_active_access_point ();

        if (active_access_point == null) {
            ssid_changed (null);
            signal_strength_changed (0);

            debug ("Kein WLAN-AccessPoint verfügbar.");
        } else {
            string ssid = (string)active_access_point.get_ssid ().data;
            ssid_changed (ssid);

            update_signal_strength ();
            active_access_point.notify["strength"].connect (update_signal_strength);

            debug ("WLAN-AccessPoint %s gefunden.", ssid);
        }
    }

    private void update_signal_strength () {
        /* Dürfe eigentlich nicht eintreten. */
        if (active_access_point == null) {
            return;
        }

        signal_strength_changed (active_access_point.get_strength ());
    }
}