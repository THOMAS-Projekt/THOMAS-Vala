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

public class THOMAS.SystemInformation : Object {
    public string network_interface { private get; construct; }

    public signal void cpu_load_changed (double cpu_load);
    public signal void memory_usage_changed (double memory_usage);
    public signal void net_load_changed (uint64 bytes_in, uint64 bytes_out);
    public signal void free_drive_space_changed (int megabytes);

    private double cpu_last_used = 0;
    private uint64 cpu_last_total = 0;

    private uint64 last_net_load_in = 0;
    private uint64 last_net_load_out = 0;

    public SystemInformation (string network_interface) {
        Object (network_interface: network_interface);
    }

    public void setup () {
        /* CPU Last initialisieren */
        get_cpu_load ();

        /* Aktuelle Netzwerk Last speichern */
        get_net_load (out last_net_load_in, out last_net_load_out);

        /* Lasten alle Sekunde aktualisieren und Signale auslösen */
        Timeout.add (1000, () => {
            /* CPU Last aktualisieren */
            cpu_load_changed (get_cpu_load ());

            /* Netzwerk Last aktualisieren */
            uint64 bytes_in, bytes_out;
            get_net_load (out bytes_in, out bytes_out);
            net_load_changed (bytes_in - last_net_load_in, bytes_out - last_net_load_out);

            /* Werte speichern */
            last_net_load_in = bytes_in;
            last_net_load_out = bytes_out;

            return true;
        });

        /* Ram-Belegung alle Sekunde aktualisieren und Signal auslösen */
        Timeout.add (5000, () => {
            /* Ram-Belegung aktualisieren */
            memory_usage_changed (get_memory_usage ());

            return true;
        });

        /* Festplatten-Speicher alle Sekunde aktualisieren und Signal auslösen */
        Timeout.add (30000, () => {
            /* Freien Speicher aktualisieren */
            free_drive_space_changed (get_free_drive_space ());

            return true;
        });
    }

    private double get_cpu_load () {
        /* CPU Daten abrufen */
        GTop.Cpu cpu_data;
        GTop.get_cpu (out cpu_data);

        /* Used speichern */
        double used = cpu_data.user + cpu_data.nice + cpu_data.sys;

        /* CPU Last zurückgeben */
        var cpu_load = (((double)used - cpu_last_used) / (cpu_data.total - cpu_last_total) * 100);

        /* Messwerte speichern */
        cpu_last_used = used;
        cpu_last_total = cpu_data.total;

        return cpu_load;
    }

    private void get_net_load (out uint64 bytes_in, out uint64 bytes_out) {
        GTop.NetLoad net_load;
        GTop.get_netload (out net_load, network_interface);

        bytes_in = net_load.bytes_in;
        bytes_out = net_load.bytes_out;
    }

    private int get_memory_usage () {
        GTop.Memory mem_data;
        GTop.get_mem (out mem_data);

        /* Benutzen Ram berechnen und als MB zurückgeben */
        return (int)((mem_data.total - mem_data.free) / 1024 / 1024);
    }

    private int get_free_drive_space () {
        GTop.FsUsage fs_usage;
        GTop.get_fsusage (out fs_usage, "/");

        /* Freien Speicherplatz ermittelnt */
        return (int)((fs_usage.bavail * fs_usage.block_size) / 1024 / 1024);
    }
}