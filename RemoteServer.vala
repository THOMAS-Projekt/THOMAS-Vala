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

[DBus (name = "thomas.server")]
public class THOMAS.RemoteServer : Object {
    public signal void cpu_load_changed (double cpu_load);
    public signal void memory_usage_changed (double memory_usage);
    public signal void net_load_changed (uint64 bytes_in, uint64 bytes_out);
    public signal void free_drive_space_changed (int megabytes);

    private Arduino? arduino = null;
    private MotorControl? motor_control = null;
    private Camera? camera = null;

    private DBusServer? dbus_server = null;

    /* Wird verwendet um Kamera-Streamern eindeutige IDs zuzuweisen. */
    private int streamer_ids = 0;

    /* Wird verwendet um Distanz-Karten eindeutige IDs zuzuweisen. */
    private int map_ids = 0;

    /* Liste der laufenden Kamerastreams */
    private Gee.HashMap<int, UDPStreamer> streamers;

    /* Liste der erstellten Umgebungskarten */
    private Gee.HashMap<int, DistanceMap> distance_maps;

    public RemoteServer (Arduino? arduino, MotorControl? motor_control, Camera? camera, uint16 port) {
        this.arduino = arduino;
        this.motor_control = motor_control;
        this.camera = camera;

        streamers = new Gee.HashMap<int, UDPStreamer> ();
        distance_maps = new Gee.HashMap<int, DistanceMap> ();

        try {
            dbus_server = new DBusServer.sync ("tcp:host=0.0.0.0,port=%u".printf (port),
                                               DBusServerFlags.AUTHENTICATION_ALLOW_ANONYMOUS,
                                               GLib.DBus.generate_guid (),
                                               null,
                                               null);

            dbus_server.new_connection.connect ((connection) => {
                try {
                    debug ("Eingehende Verbindung.");

                    connection.register_object ("/thomas/server", this);

                    return true;
                } catch (Error e) {
                    warning ("Annehmen der eingehenden Verbindung fehlgeschlagen: %s", e.message);

                    return false;
                }
            });

            dbus_server.start ();

            debug ("Steuerungsserver gestartet: %s", dbus_server.get_client_address ());
        } catch (Error e) {
            warning ("Steuerungsserver konnte nicht gestartet werden: %s", e.message);
        }
    }

    ~RemoteServer () {
        if (dbus_server != null) {
            dbus_server.stop ();
            debug ("Steuerungsserver gestoppt.");
        }
    }

    public bool set_motor_speed (uint8 motor, int speed) {
        if (motor_control == null) {
            return false;
        }

        motor_control.set_motor_speed (MotorControl.Motor.from_number (motor), (short)speed);

        return true;
    }

    public bool accelerate_to_motor_speed (uint8 motor, int speed) {
        if (motor_control == null) {
            return false;
        }

        motor_control.accelerate_to_motor_speed (MotorControl.Motor.from_number (motor), (short)speed);

        return true;
    }

    public bool set_cam_position (uint8 camera, uint8 angle) {
        if (arduino == null) {
            return false;
        }

        arduino.set_cam_position (camera, angle);

        return true;
    }

    public bool change_cam_position (uint8 camera, uint8 degree) {
        if (arduino == null) {
            return false;
        }

        arduino.change_cam_position (camera, degree);

        return true;
    }

    public int start_camera_stream (string viewer_host, uint16 viewer_port) {
        if (camera == null) {
            return -1;
        }

        int streamer_id = streamer_ids++;

        UDPStreamer streamer = new UDPStreamer (camera, viewer_host, viewer_port);

        if (streamer.setup ()) {
            streamer.start ();

            camera.start ();

            streamers.@set (streamer_id, streamer);
        }

        return streamer_id;
    }

    public bool stop_camera_stream (int streamer_id) {
        if (camera == null) {
            return false;
        }

        streamers.unset (streamer_id);

        camera.stop ();

        return true;
    }

    public bool set_camera_stream_options (int streamer_id, int image_quality, int image_density) {
        if (camera == null) {
            return false;
        }

        if (streamers.has_key (streamer_id)) {
            UDPStreamer streamer = streamers.@get (streamer_id);
            streamer.image_quality = image_quality > 100 ? 100 : image_quality < 0 ? 0 : image_quality;
            streamer.image_density = image_density > 100 ? 100 : image_density < 0 ? 0 : image_density;
        }

        return true;
    }

    public int start_new_scan () {
        if (arduino == null) {
            return -1;
        }

        int map_id = map_ids++;

        DistanceMap distance_map = new DistanceMap (arduino);
        distance_map.setup ();

        distance_maps.@set (map_id, distance_map);

        return map_id;
    }
}