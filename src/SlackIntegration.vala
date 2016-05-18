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

public class THOMAS.SlackIntegration : Soup.Session {
    private static const string API_PATH = "https://slack.com/api/%s";
    private static const string OWN_USER_ID = "U0M6433FS";
    private static const string DIRECT_CHANNEL_ID = "D0M63HC4S";
    private static const bool REQUIRE_MENTIONS = true;

    public Camera? camera { private get; construct; }
    public string api_token { private get; construct; }

    private Soup.WebsocketConnection? rtm_connection = null;

    private int rtm_api_request_id = 0;

    public SlackIntegration (Camera? camera, string api_token) {
        Object (camera : camera, api_token : api_token);

        this.use_thread_context = true;
    }

    public void setup () {
        string? websocket_url = query_websocket_url ();

        if (websocket_url == null) {
            warning ("Anforderung der Slack-Websocket-URL fehlgeschlagen.");

            return;
        }

        debug ("Verbinde zur Slack-RTM-API...");

        connect_to_rtm_api (websocket_url.replace ("wss://", "https://"));
    }

    private string? query_websocket_url () {
        Json.Object? response = send_web_api_request ("rtm.start", { "simple_latest", "true",
                                                                      "no_unreads", "true" });

        if (response == null) {
            return null;
        }

        return response.get_string_member ("url");
    }

    private void connect_to_rtm_api (string websocket_url) {
        Soup.Message message = new Soup.Message ("GET", websocket_url);

        this.websocket_connect_async.begin (message, null, null, null, (obj, res) => {
            try {
                rtm_connection = this.websocket_connect_async.end (res);
                rtm_connection.message.connect ((type, data) => {
                    string response_string = (string)data.get_data ();
                    Json.Object? response = json_string_to_object (response_string);

                    if (response == null || !response.has_member ("type")) {
                        return;
                    }

                    switch (response.get_string_member ("type")) {
                        case "hello" :
                            debug ("Verbindung zur Slack-RTM-API hergestellt.");

                            break;
                        case "message" :

                            if (!response.has_member ("channel") || !response.has_member ("text") || !response.has_member ("user")) {
                                return;
                            }

                            string channel = response.get_string_member ("channel");
                            string text = response.get_string_member ("text");
                            string user = response.get_string_member ("user");

                            if (user != OWN_USER_ID &&
                                (!REQUIRE_MENTIONS ||
                                 channel == DIRECT_CHANNEL_ID ||
                                 text.contains ("<@%s>".printf (OWN_USER_ID)))) {
                                process_command (text, channel);
                            }

                            break;
                    }
                });
                rtm_connection.error.connect ((error) => {
                    warning ("Fehler des Slack-RTM-Websockets: %s", error.message);
                });
                rtm_connection.closed.connect (() => {
                    warning ("Verbindung mit Slack-RTM-Websocket unterbrochen. Verbinde erneut...");

                    setup ();
                });

                Timeout.add (30000, () => {
                    Json.Object ping_object = new Json.Object ();
                    ping_object.set_int_member ("id", rtm_api_request_id++);
                    ping_object.set_string_member ("type", "ping");

                    send_rtm_api_request (ping_object);

                    return true;
                });
            } catch (Error e) {
                warning ("Verbindung mit Slack-RTM-API fehlgeschlagen: %s", e.message);
            }
        });
    }

    private Json.Object? send_web_api_request (string method, string[] parameters, string? file_field_name = null, string? filename = null, string? file_type = null, uint8[]? file_data = null) {
        Soup.Multipart multipart = new Soup.Multipart ("multipart/form-data");
        multipart.append_form_string ("token", api_token);

        for (int i = 0; i < parameters.length - 1; i += 2) {
            multipart.append_form_string (parameters[i], parameters[i + 1]);
        }

        if (file_field_name != null && filename != null && file_type != null && file_data != null) {
            multipart.append_form_file (file_field_name, filename, file_type, new Soup.Buffer.take (file_data));
        }

        Soup.Message message = Soup.Form.request_new_from_multipart (API_PATH.printf (method), multipart);
        uint status_code = this.send_message (message);

        if (status_code != Soup.Status.OK) {
            warning ("Verbindung mit Slack-Web-API fehlgeschlagen: %s", Soup.Status.get_phrase (status_code));

            return null;
        }

        string response_string = (string)message.response_body.data;
        Json.Object? response = json_string_to_object (response_string);

        if (response == null) {
            warning ("Anfrage an Slack-Web-API fehlgeschlagen: %s", response_string);

            return null;
        }

        if (!response.get_boolean_member ("ok") && response.has_member ("error")) {
            warning ("Slack-Web-API Fehler: %s", response.get_string_member ("error"));

            return null;
        }

        if (response.has_member ("warning")) {
            warning ("Slack-Web-API Warnung: %s", response.get_string_member ("warning"));
        }

        return response;
    }

    private void send_rtm_api_request (Json.Object request) {
        string request_string = json_object_to_string (request);

        rtm_connection.send_text (request_string);
    }

    private void process_command (string command, string channel) {
        new Thread<int> (null, () => {
            debug ("Verarbeite Befehl: %s", command);

            if (string_contains (command.down (), { "mache", "nehme", "nimm", "foto", "bild", "aufnehmen" }, 2)) {
                send_camera_picture (channel);
            } else if (string_contains (command.down (), { "wie ist", "wie lautet", "ip", "adresse" }, 2)) {
                send_ifconfig (channel);
            } else if (string_contains (command.down (), { "hallo", "hello", "moin", "hi" })) {
                send_web_api_request ("chat.postMessage", { "channel", channel,
                                                            "as_user", "true",
                                                            "text", random_answer ({ "Moin!", "Wie geht's?", "Hey, schön dich zu sehen!", "What!? Es gibt Menschen in diesem Channel?" }) });
            } else if (string_contains (command.down (), { "du", "dein", "dich", "heißt", "bedeutet", "name", "thomas", "wofür steht", "heißt", "bedeutet", "bezeichnung", "nennen" }, 2)) {
                send_web_api_request ("chat.postMessage", { "channel", channel,
                                                            "as_user", "true",
                                                            "text", "Die Abkürzung THOMAS steht für _Terrestrial Hightech Observation Machinery and Autonomous System_" });
            } else if (string_contains (command.down (), { "ja", "jo", "jo", "genau", "ne", "nein" })) {
                send_web_api_request ("chat.postMessage", { "channel", channel,
                                                            "as_user", "true",
                                                            "text", "Hätte ich nicht gedacht..." });
            }

            return 0;
        });
    }

    private void send_camera_picture (string channel) {
        if (camera == null) {
            return;
        }

        camera.start ();

        int capturing_tries = 0;

        Timeout.add (1000, () => {
            if (camera.last_frame == null) {
                if (capturing_tries++ > 10) {
                    warning ("Aufnahme eines Einzelbildes für die Slack-Integration fehlgeschlagen.");

                    camera.stop ();

                    return false;
                }

                return true;
            }

            Gdk.Pixbuf frame = camera.last_frame;
            uint8[] frame_data;

            try {
                if (!frame.save_to_buffer (out frame_data, "jpeg", "quality", "90")) {
                    warning ("Konvertieren des Einzelbildes für die Slack-Integration fehlgeschlagen.");

                    return false;
                }
            } catch (Error e) {
                warning ("Konvertieren des Einzelbildes für die Slack-Integration fehlgeschlagen: %s", e.message);

                return false;
            }

            new Thread<int> (null, () => {
                send_web_api_request ("files.upload", { "as_user", "true",
                                                        "filename", "Einzelbild.jpg",
                                                        "channels", channel },
                                      "file", "frame.jpg", "image/jpeg", frame_data);
                return 0;
            });

            camera.stop ();

            return false;
        });
    }

    private void send_ifconfig (string channel) {
        try {
            string output;

            Process.spawn_sync (null, { "/sbin/ifconfig" }, Environ.@get (), SpawnFlags.SEARCH_PATH, null, out output);

            new Thread<int> (null, () => {
                send_web_api_request ("chat.postMessage", { "channel", channel,
                                                            "as_user", "true",
                                                            "text", "```%s```".printf (output) });

                return 0;
            });
        } catch (Error e) {
            warning ("Abrufen der Netzwerkinformationen für die Slack-Integration fehlgeschlagen: %s", e.message);
        }
    }

    private bool string_contains (string text, string[] keywords, int min_matches = 1) {
        int matches = 0;

        foreach (string keyword in keywords) {
            if (text.contains (keyword)) {
                matches++;
            }
        }

        return matches >= min_matches;
    }

    private string random_answer (string[] answers) {
        return answers[Random.int_range (0, answers.length)];
    }

    private string json_object_to_string (Json.Object json_object) {
        Json.Node root = new Json.Node (Json.NodeType.OBJECT);
        root.set_object (json_object);

        Json.Generator generator = new Json.Generator ();
        generator.root = root;

        return generator.to_data (null);
    }

    private Json.Object? json_string_to_object (string json_string) {
        Json.Parser parser = new Json.Parser ();

        try {
            parser.load_from_data (json_string);

            return parser.get_root ().get_object ();
        } catch (Error e) {
            warning ("Parsen des JSON-Strings fehlgeschlagen: %s", e.message);

            return null;
        }
    }
}
