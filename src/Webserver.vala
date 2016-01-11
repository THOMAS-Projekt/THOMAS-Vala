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

public class THOMAS.Webserver : Neutron.Http.Server {
    public RemoteServer remote_server { private get; construct; }

    public string html_directory { private get; construct; }

    private Gee.ArrayList<Neutron.Websocket.Connection> connections;

    construct {
        connections = new Gee.ArrayList<Neutron.Websocket.Connection> ();
    }

    public Webserver (RemoteServer remote_server, string html_directory, uint16 port) {
        Object (remote_server: remote_server, html_directory: html_directory);

        this.select_entity.connect (connection_handler);
        this.port = port;

        debug ("Webserver auf Port %u gestartet.", port);

        connect_signals ();
    }

    private void connect_signals () {
        remote_server.camera_stream_registered.connect ((streamer_id) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("streamerId", streamer_id);

            broadcast_signal ("cameraStreamRegistered", args);
        });

        remote_server.distance_map_registered.connect ((map_id) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("mapId", map_id);

            broadcast_signal ("distanceMapRegistered", args);
        });

        remote_server.wifi_ssid_changed.connect ((ssid) => {
            Json.Object args = new Json.Object ();
            args.set_string_member ("ssid", ssid);

            broadcast_signal ("wifiSsidChanged", args);
        });

        remote_server.wifi_signal_strength_changed.connect ((signal_strength) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("signalStrength", signal_strength);

            broadcast_signal ("wifiSignalStrengthChanged", args);
        });

        remote_server.cpu_load_changed.connect ((cpu_load) => {
            Json.Object args = new Json.Object ();
            args.set_double_member ("cpuLoad", cpu_load);

            broadcast_signal ("cpuLoadChanged", args);
        });

        remote_server.memory_usage_changed.connect ((memory_usage) => {
            Json.Object args = new Json.Object ();
            args.set_double_member ("memoryUsage", memory_usage);

            broadcast_signal ("memoryUsageChanged", args);
        });

        remote_server.net_load_changed.connect ((bytes_in, bytes_out) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("bytesIn", (int64)bytes_in);
            args.set_int_member ("bytesOut", (int64)bytes_out);

            broadcast_signal ("netLoadChanged", args);
        });

        remote_server.free_drive_space_changed.connect ((megabytes) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("megabytes", megabytes);

            broadcast_signal ("freeDriveSpaceChanged", args);
        });

        remote_server.map_scan_continued.connect ((map_id, angle, step_distances) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("mapId", map_id);
            args.set_int_member ("angle", angle);

            Json.Array distances_array = new Json.Array ();

            foreach (uint16 distance in step_distances) {
                distances_array.add_int_element (distance);
            }

            args.set_array_member ("stepDistances", distances_array);

            broadcast_signal ("mapScanContinued", args);
        });

        remote_server.map_scan_finished.connect ((map_id) => {
            Json.Object args = new Json.Object ();
            args.set_int_member ("mapId", map_id);

            broadcast_signal ("mapScanFinished", args);
        });
    }

    private void connection_handler (Neutron.Http.Request request, Neutron.Http.EntitySelectContainer container) {
        debug ("Eingehende Webserver-Verbindung auf %s.", request.path);

        if (request.path == "/socket") {
            container.set_entity (create_websocket_entity ());

            return;
        }

        container.set_entity (create_file_entity (request.path));
    }

    private Neutron.Http.Entity create_websocket_entity () {
        Neutron.Websocket.HttpUpgradeEntity entity = new Neutron.Websocket.HttpUpgradeEntity (false);
        entity.incoming.connect (websocket_connection_handler);

        debug ("Eingehende Websocket-Verbindung");

        return entity;
    }

    private Neutron.Http.Entity create_file_entity (string path) {
        File file = File.new_for_path ("%s/%s".printf (html_directory, (path == "/" ? "/index.html" : path.replace ("..", ""))));

        string? filename = file.get_path ();

        if (!file.query_exists () || filename == null) {
            warning ("Datei \"%s\" nicht gefunden.", filename ?? path);

            return new Neutron.Http.NotFoundEntity ();
        }

        string? basename = file.get_basename ();

        if (basename == null) {
            warning ("\"%s\" ist keine Datei.", filename);

            return new Neutron.Http.NotFoundEntity ();
        }

        string[] basename_parts = basename.split (".");
        string? mime_type = ContentType.get_mime_type (basename_parts[basename_parts.length - 1]);

        if (mime_type == null) {
            warning ("Dateityp von \"%s\" unbekannt.", filename);

            return new Neutron.Http.NotFoundEntity ();
        }

        return new Neutron.Http.FileEntity (mime_type, filename);
    }

    private void websocket_connection_handler (Neutron.Websocket.Connection connection) {
        connection.on_message.connect (process_request);
        connection.on_error.connect ((message, connection) => {
            warning ("Websocket-Fehler: %s", message);
        });
        connection.on_close.connect ((connection) => {
            debug ("Websocket-Verbindung geschlossen.");

            connections.remove (connection);
        });
        connection.start ();

        connections.add (connection);
    }

    private void process_request (string message, Neutron.Websocket.Connection connection) {
        Json.Parser parser = new Json.Parser ();

        try {
            parser.load_from_data (message);

            Json.Node? request_root = parser.get_root ();

            if (request_root == null) {
                warning ("Parsen der Anfrage fehlgeschlagen:\n%s", message);

                return;
            }

            Json.Object request = request_root.get_object ();

            string action = request.get_string_member ("action");
            string method_name = request.get_string_member ("methodName");
            string response_id = request.get_string_member ("responseId");
            Json.Object args = request.get_object_member ("args");

            Json.Object response = new Json.Object ();

            if (action != "callMethod") {
                warning ("Aktion \"%s\" nicht bekannt.", action);

                return;
            }

            response.set_string_member ("action", "methodResponse");
            response.set_string_member ("methodName", method_name);
            response.set_string_member ("responseId", response_id);

            switch (method_name) {
                case "setMotorSpeed" :
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.set_motor_speed (MotorControl.Motor.from_name (args.get_string_member ("motor")),
                                                                                (int)args.get_int_member ("speed")));

                    break;

                case "accelerateToMotorSpeed" :
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.accelerate_to_motor_speed (MotorControl.Motor.from_name (args.get_string_member ("motor")),
                                                                                          (int)args.get_int_member ("speed")));

                    break;

                case "setCamPosition" :
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.set_cam_position ((uint8)args.get_int_member ("camera"),
                                                                                 (uint8)args.get_int_member ("angle")));

                    break;

                case "changeCamPosition" :
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.change_cam_position ((uint8)args.get_int_member ("camera"),
                                                                                    (uint8)args.get_int_member ("degree")));

                    break;

                case "setRelay":
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.set_relay ((int)args.get_int_member ("port"),
                                                                          args.get_boolean_member ("state")));

                    break;

                case "startCameraStream":
                    response.set_int_member ("returnedValue",
                                             remote_server.start_camera_stream (args.get_string_member ("viewerHost"),
                                                                                (uint16)args.get_int_member ("viewerPort")));

                    break;

                case "stopCameraStream":
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.stop_camera_stream ((int)args.get_int_member ("streamerId")));

                    break;

                case "setCameraStreamOptions":
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.set_camera_stream_options ((int)args.get_int_member ("streamerId"),
                                                                                          (int)args.get_int_member ("imageQuality"),
                                                                                          (int)args.get_int_member ("imageDensity")));

                    break;

                case "startNewScan":
                    response.set_int_member ("returnedValue", remote_server.start_new_scan ());

                    break;

                case "stopScan":
                    response.set_boolean_member ("returnedValue",
                                                 remote_server.stop_scan ((int)args.get_int_member ("mapId")));

                    break;

                case "forceTelemetryUpdate":
                    response.set_boolean_member ("returnedValue", remote_server.force_telemetry_update ());

                    break;

                default:
                    warning ("Methode \"%s\" nicht bekannt.", method_name);

                    break;
            }

            Json.Node response_root = new Json.Node (Json.NodeType.OBJECT);
            response_root.set_object (response);

            Json.Generator generator = new Json.Generator ();
            generator.set_root (response_root);

            connection.send.begin (generator.to_data (null));
        } catch (Error e) {
            warning ("Parsen der Anfrage fehlgeschlagen: %s\n%s", e.message, message);
        }
    }

    private void broadcast_signal (string signal_name, Json.Object args) {
        Json.Object response = new Json.Object ();
        response.set_string_member ("action", "signalCalled");
        response.set_string_member ("signalName", signal_name);
        response.set_object_member ("args", args);

        Json.Node response_root = new Json.Node (Json.NodeType.OBJECT);
        response_root.set_object (response);

        Json.Generator generator = new Json.Generator ();
        generator.set_root (response_root);

        broadcast_message (generator.to_data (null));
    }

    private void broadcast_message (string message) {
        foreach (Neutron.Websocket.Connection connection in connections) {
            connection.send.begin (message);
        }
    }
}