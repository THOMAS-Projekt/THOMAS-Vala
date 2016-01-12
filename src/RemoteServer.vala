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
    public signal void camera_stream_registered (int streamer_id);
    public signal void distance_map_registered (int map_id);

    public signal void wifi_ssid_changed (string ssid);
    public signal void wifi_signal_strength_changed (uint8 signal_strength);
    public signal void cpu_load_changed (double cpu_load);
    public signal void memory_usage_changed (double memory_usage);
    public signal void net_load_changed (uint64 bytes_in, uint64 bytes_out);
    public signal void free_drive_space_changed (int megabytes);

    public signal void map_scan_continued (int map_id, uint8 angle, uint16[] step_distances);
    public signal void map_scan_finished (int map_id);

    private Arduino? arduino = null;
    private MotorControl? motor_control = null;
    private Relais? relais = null;
    private Camera? camera = null;
    private NetworkManager network_manager;
    private SystemInformation system_information;

    private DBusServer? dbus_server = null;

    /* Wird verwendet um Kamera-Streamern eindeutige IDs zuzuweisen. */
    private int streamer_ids = 0;

    /* Wird verwendet um Distanz-Karten eindeutige IDs zuzuweisen. */
    private int map_ids = 0;

    /* Zählt die laufenden Scanvorgänge. */
    private int running_scans = 0;

    /* Liste der laufenden Kamerastreams */
    private Gee.HashMap<int, UDPStreamer> streamers;

    /* Liste der erstellten Umgebungskarten */
    private Gee.HashMap<int, DistanceMap> distance_maps;

    private MappingAlgorithm? mapping_algorithm = null;

    public RemoteServer (Arduino? arduino, MotorControl? motor_control, Relais? relais, Camera? camera, NetworkManager network_manager, SystemInformation system_information, uint16 port) {
        this.arduino = arduino;
        this.motor_control = motor_control;
        this.relais = relais;
        this.camera = camera;
        this.network_manager = network_manager;
        this.system_information = system_information;

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
                    debug ("Eingehende DBus-Verbindung.");

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

    public bool set_relay (int port, bool state) {
        if (relais == null) {
            return false;
        }

        relais.set_relay (port, state);

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

            camera_stream_registered (streamer_id);
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
        distance_map.scan_continued.connect ((angle, step_distances) => {
            map_scan_continued (map_id, angle, step_distances);

            if (mapping_algorithm != null) {
                int sum = 0;

                foreach (uint16 distance in step_distances) {
                    sum += distance;
                }

                mapping_algorithm.handle_map_scan_continued (map_id, angle, (uint16)(sum / step_distances.length));
            }
        });
        distance_map.scan_finished.connect (() => {
            map_scan_finished (map_id);
            running_scans--;

            reset_scanner_position ();

            if (mapping_algorithm != null) {
                mapping_algorithm.handle_map_scan_finished (map_id);
            }
        });

        distance_maps.@set (map_id, distance_map);

        distance_map_registered (map_id);

        running_scans++;

        return map_id;
    }

    public bool stop_scan (int map_id) {
        if (arduino == null) {
            return false;
        }

        DistanceMap? distance_map;
        distance_maps.unset (map_id, out distance_map);

        if (distance_map != null) {
            if (distance_map.stop ()) {
                running_scans--;
            }
        }

        reset_scanner_position ();

        return true;
    }

    public bool force_telemetry_update () {
        network_manager.force_update ();
        system_information.force_update ();

        return true;
    }

    public bool set_automation_state (bool enable) {
        if (enable) {
            if (mapping_algorithm != null) {
                return false;
            }

            mapping_algorithm = new MappingAlgorithm ((speed, duration) => {
                accelerate_to_motor_speed (MotorControl.Motor.BOTH, speed);

                Timeout.add (duration, () => {
                    accelerate_to_motor_speed (MotorControl.Motor.BOTH, 0);

                    return false;
                });
            }, (speed, duration) => {
                set_motor_speed (MotorControl.Motor.LEFT, speed);
                set_motor_speed (MotorControl.Motor.RIGHT, -speed);

                Timeout.add (duration, () => {
                    set_motor_speed (MotorControl.Motor.BOTH, 0);

                    return false;
                });
            }, start_new_scan);
        } else {
            if (mapping_algorithm == null) {
                return false;
            }

            mapping_algorithm = null;
        }

        debug ("Autonome Steuerung %s.", enable ? "aktiviert" : "deaktiviert");

        return true;
    }

    private void reset_scanner_position () {
        if (running_scans <= 0) {
            set_cam_position (0, 105);
            running_scans = 0;
        }
    }
}