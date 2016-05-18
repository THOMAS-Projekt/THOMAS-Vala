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
        { "network-interface", 'N', 0, OptionArg.STRING, ref network_interface, "Das fuer Statistiken zu benutzende Netzwerkinterface", "INTERFACE" },
        { "no-network-manager", 'n', 0, OptionArg.NONE, ref no_network_manager, "Nicht mit dem Network-Manager verbinden", null },
        { "webserver-port", 'W', 0, OptionArg.INT, ref webserver_port, "Port des Webservers", "PORT" },
        { "slack-token", 'S', 0, OptionArg.STRING, ref slack_api_token, "API-Token für die Slack-Integration", "TOKEN/NONE" },
        { "enable-minimalmode", 'm', 0, OptionArg.NONE, ref enable_minimalmode, "Aktiviert den Minimalmodus des Arduinos", null },
        { "html-directory", 'H', 0, OptionArg.STRING, ref html_directory, "Pfad zum HTML-Verzeichnis", "PFAD" },
        { null }
    };

    private static bool debug_mode = false;
    private static string? arduino_tty = null;
    private static string? motor_tty = null;
    private static string? relais_tty = null;
    private static int camera_id = 0;
    private static string? network_interface = null;
    private static bool no_network_manager = false;
    private static int webserver_port = 8080;
    private static string? slack_api_token = null;
    private static bool enable_minimalmode = false;
    private static string? html_directory = null;

    public static void main (string[] args) {
        if (!Thread.supported ()) {
            warning ("Threads werden möglicherweise nicht unterstützt.");
        }

        var options = new OptionContext ("Server starten");
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
    private NetworkManager? network_manager = null;
    private Arduino? arduino = null;
    private MotorControl? motor_control = null;
    private Relais? relais = null;
    private Camera? camera = null;
    private RemoteServer remote_server;
    private Webserver webserver;
    private SlackIntegration? slack_integration = null;
    private ServiceProvider service_provider;
    private SystemInformation system_information;

    public Main () {
        main_loop = new MainLoop ();

        debug ("Initialisiere Logger...");
        {
            logger = new Logger ();
            logger.set_debug_mode (debug_mode);
        }

        if (!no_network_manager) {
            debug ("Initialisiere Netzwerk-Manager...");
            {
                network_manager = new NetworkManager ();
            }
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

        debug ("Initialisiere Systemmonitor...");
        {
            system_information = new SystemInformation (network_interface == null ? "wlan0" : network_interface);
            system_information.setup ();
        }

        debug ("Initialisiere Steuerungsserver...");
        {
            remote_server = new RemoteServer (arduino, motor_control, relais, camera, network_manager, system_information, 4242);
        }

        debug ("Initialisiere Webserver...");
        {
            try {
                webserver = new Webserver (remote_server, html_directory == null ? Environment.get_current_dir () : html_directory);
                webserver.listen_all (webserver_port, 0);

                debug ("Webserver auf Port %i gestartet.", webserver_port);
            } catch (Error e) {
                warning ("Webserver konnte nicht gestartet werden: %s", e.message);
            }
        }

        if (slack_api_token != null && slack_api_token.down () != "none") {
            debug ("Initialisiere Slack-Integration...");
            {
                slack_integration = new SlackIntegration (camera, slack_api_token);
                slack_integration.setup ();
            }
        }

        debug ("Initialisiere Avahi-Dienst...");
        {
            service_provider = new ServiceProvider (4242);
            service_provider.setup ();
        }

        debug ("Verknüpfe Ereignisse...");
        {
            connect_signals ();
        }

        debug ("Starte Terminal-Handler...");
        {
            run_terminal_handler ();
        }

        info ("Initialisierung abgeschlossen.");

        main_loop.run ();
    }

    private void connect_signals () {
        if (network_manager != null) {
            network_manager.ssid_changed.connect ((ssid) => {
                string checked_ssid = (ssid == null ? "Nicht verbunden" : ssid);

                remote_server.wifi_ssid_changed (checked_ssid);

                if (arduino != null) {
                    arduino.update_ssid (checked_ssid);
                }
            });

            network_manager.signal_strength_changed.connect ((signal_strength) => {
                remote_server.wifi_signal_strength_changed (signal_strength);

                if (arduino != null) {
                    arduino.update_signal_strength (signal_strength);
                }
            });
        }

        system_information.cpu_load_changed.connect ((cpu_load) => {
            remote_server.cpu_load_changed (cpu_load);
        });

        system_information.memory_usage_changed.connect ((memory_usage) => {
            remote_server.memory_usage_changed (memory_usage);
        });

        system_information.net_load_changed.connect ((bytes_in, bytes_out) => {
            remote_server.net_load_changed (bytes_in, bytes_out);
        });

        system_information.free_drive_space_changed.connect ((megabytes) => {
            remote_server.free_drive_space_changed (megabytes);
        });
    }

    private void run_terminal_handler () {
        new Thread<int> (null, () => {
            while (true) {
                string? line = stdin.read_line ();

                if (line == null || line.strip () == "") {
                    continue;
                }

                switch (line.split (" ")[0].down ()) {
                    case "exit" :
                    case "stop" :
                        main_loop.quit ();

                        return 0;
                    default :
                        warning ("Unbekannter Befehl.");

                        break;
                }
            }
        });
    }
}
