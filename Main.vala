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

public class THOMAS.Main : Object {
    private static const OptionEntry[] OPTIONS = {
        { "debug", 'd', 0, OptionArg.NONE, ref debug_mode, "Aktiviert den Debugmodus", null },
        { "arduino-tty", 'A', 0, OptionArg.STRING, ref arduino_tty, "Port des Arduinos", "PORT/NONE" },
        { "motor-tty", 'M', 0, OptionArg.STRING, ref motor_tty, "Port der Motorsteuerung", "PORT/NONE" },
        { "relais-tty", 'R', 0, OptionArg.STRING, ref relais_tty, "Port der Relaiskarte", "PORT/NONE" },
        { "camera", 'C', 0, OptionArg.INT, ref camera_id, "ID der Kamera", "ID/-1" },
        { "enable-minimalmode", 'm', 0, OptionArg.NONE, ref enable_minimalmode, "Aktiviert den Minimalmodus des Arduinos", null },
        { null }
    };

    private static bool debug_mode = false;
    private static string? arduino_tty = null;
    private static string? motor_tty = null;
    private static string? relais_tty = null;
    private static int camera_id = 0;
    private static bool enable_minimalmode = false;

    public static void main (string[] args) {
        if (!Thread.supported ()) {
            warning ("Threads werden möglicherweise nicht unterstützt.");
        }

        var options = new OptionContext ("Beispiel");
        options.set_help_enabled (true);
        options.add_main_entries (OPTIONS, null);

        try {
            options.parse (ref args);
        } catch (Error e) {
            error ("Parsen der Parameter fehlgeschlagen.");
        }

        new Main ();
    }

    private MainLoop main_loop;

    private Logger logger;
    private NetworkManager network_manager;
    private Arduino? arduino = null;
    private MotorControl? motor_control = null;
    private Relais? relais = null;
    private Camera? camera = null;
    private RemoteServer remote_server;

    public Main () {
        main_loop = new MainLoop ();

        debug ("Initialisiere Logger...");
        {
            logger = new Logger ();
            logger.set_debug_mode (debug_mode);
        }

        debug ("Initialisiere Netzwerk-Manager...");
        {
            network_manager = new NetworkManager ();
        }

        if (arduino_tty == null || arduino_tty.down () != "none") {
            debug ("Initialisiere Arduino...");
            {
                arduino = new Arduino (arduino_tty == null ? "/dev/ttyACM0" : arduino_tty, enable_minimalmode);
                arduino.wait_for_initialisation ();
                arduino.setup ();
            }
        }

        if (motor_tty == null || motor_tty.down () != "none") {
            debug ("Initialisiere Motorsteuerung...");
            {
                motor_control = new MotorControl (motor_tty == null ? "/dev/ttyS0" : motor_tty);
                motor_control.setup ();
            }
        }

        if (relais_tty == null || relais_tty.down () != "none") {
            debug ("Initialisiere Relaiskarte...");
            {
                relais = new Relais (relais_tty == null ? "/dev/ttyUSB0" : relais_tty);
                relais.setup ();
                relais.set_all (false);
            }
        }

        if (camera_id >= 0) {
            debug ("Initialisiere Kamera...");
            {
                camera = new Camera (camera_id == -1 ? 0 : camera_id);
            }
        }

        debug ("Initialisiere Steuerungsserver...");
        {
            remote_server = new RemoteServer (arduino, motor_control, camera, 4242);
        }

        debug ("Verknüpfe Ereignisse...");
        {
            connect_signals ();
        }

        info ("Initialisierung abgeschlossen.");

        main_loop.run ();
    }

    private void connect_signals () {
        network_manager.ssid_changed.connect ((ssid) => {
            if (arduino == null) {
                return;
            }

            arduino.update_ssid (ssid == null ? "Nicht verbunden" : ssid);
        });

        network_manager.signal_strength_changed.connect ((signal_strength) => {
            if (arduino == null) {
                return;
            }

            arduino.update_signal_strength (signal_strength);
        });

        /* Consolenhandler */
        Idle.add (() => {
            string? line = stdin.read_line ();

            if (line == null || line.strip () == "") {
                return true;
            }

            switch (line.split (" ")[0].down ()) {
                case "exit" :
                case "stop" :
                    main_loop.quit ();

                    return false;
                default :
                    warning ("Unbekannter Befehl.");

                    break;
            }

            return true;
        });
    }
}