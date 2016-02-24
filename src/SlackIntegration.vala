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

    public string api_token { private get; construct; }

    public SlackIntegration (string api_token) {
        Object (api_token: api_token);
    }

    public void setup () {
        string? websocket_url = query_websocket_url ();

        if (websocket_url == null) {
            warning ("Anforderung der Slack-Websocket-URL fehlgeschlagen.");

            return;
        }

        debug ("Verbinde zur Slack-RTM-API...");

        /* TODO */

        /*
         * Verbindung erfolgreich hergestellt bei "hello" event.
         * komplexe messages müssen via web api gesendet werden mit as_user=true
         * ping message alle paar sekunden?? vorteile?
         * jede anfrage max. 16kb! max. 1 message pro sekunde im durchschnitt
         * => Am besten möglichst viel über web api lösen, nur events und ping über rtm.
         */
    }

    private string? query_websocket_url () {
        Json.Object? response = send_web_api_request ("rtm.start", "simple_latest=true&no_unreads=true");

        if (response == null) {
            return null;
        }

        return response.get_string_member ("url");
    }

    private Json.Object? send_web_api_request (string method, string? parameters = null) {
        string request_string = "token=%s".printf (api_token);

        if (parameters != null) {
            request_string += "&%s".printf (parameters);
        }

        Soup.Message message = new Soup.Message ("POST", API_PATH.printf (method));
        message.set_request ("application/x-www-form-urlencoded", Soup.MemoryUse.COPY, request_string.data);

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

        if (!response.get_boolean_member ("ok")) {
            warning ("Slack-Web-API Fehler: %s", response.get_string_member ("error"));

            return null;
        }

        if (response.has_member ("warning")) {
            warning ("Slack-Web-API Warnung: %s", response.get_string_member ("warning"));
        }

        return response;
    }

    private void send_rtm_api_request (Json.Object request) {
        /* TODO */

        /* einmalige id inner request */
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