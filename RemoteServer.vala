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
    private Arduino? arduino = null;
    private MotorControl? motor_control = null;
    private Camera? camera = null;

    private DBusServer dbus_server;

    /* Wird verwendet um Kamera-Streamern eindeutige IDs zuzuweisen. */
    private int streamer_ids = 0;

    public RemoteServer (Arduino? arduino, MotorControl? motor_control, Camera? camera, uint16 port) {
        this.arduino = arduino;
        this.motor_control = motor_control;
        this.camera = camera;

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

        UDPStreamer streamer = new UDPStreamer (camera, viewer_host, viewer_port);
        streamer.setup ();

        return streamer_ids++;
    }
}