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

public class THOMAS.UDPStreamer : Object {
    private static const uint32 MAX_PACKAGE_SIZE = 64000;

    public Camera camera { private get; construct; }

    private string hostname;
    private uint16 port;

    /* Streamkonfiguration mit Prozentwerten */
    public int image_quality { get; set; default = 70; }
    public int image_density { get; set; default = 100; }

    private SocketClient client;

    /*
     * Erstellt einen neuen UDP-Streamer zum Senden des Kamerastreams an ein Anzeigeprogramm.
     * Die Existenz einer Kameraverbindung sollte vorm Instanzieren überprüft werden.
     */
    public UDPStreamer (Camera camera, string hostname, uint16 port) {
        Object (camera: camera);

        this.hostname = hostname;
        this.port = port;

        client = new SocketClient ();
        client.protocol = SocketProtocol.UDP;
    }

    public void setup () {
        OutputStream output_stream;

        try {
            debug ("Verbinde zu %s:%u...", hostname, port);

            SocketConnection connection = client.connect_to_host (hostname, port);
            output_stream = connection.output_stream;
        } catch (Error e) {
            warning ("Verbindung fehlgeschlagen: %s", e.message);

            return;
        }

        debug ("Verbindung hergestellt, Übertragung wird gestartet...");

        camera.frame_captured.connect ((frame) => {
            try {
                uint8[] frame_data;

                /* Frame kodieren und in Byte-Array konvertieren */
                if (!frame.save_to_buffer (out frame_data, "jpeg",
                                           "quality", image_quality,
                                           "x-dpi", image_density,
                                           "y-dpi", image_density)) {
                    warning ("Konvertieren und Exportieren des Kamera-Frames fehlgeschlagen.");

                    return;
                }

                uint32 bytes_sent = 0;

                while (bytes_sent < frame_data.length) {
                    /* Größe des Nächsten Paketes bestimmen */
                    uint32 next_size = frame_data.length - bytes_sent;

                    /* Zu große Pakete kürzen */
                    if (next_size > MAX_PACKAGE_SIZE) {
                        next_size = MAX_PACKAGE_SIZE;
                    }

                    /* Ausschnitt aus Daten-Array wählen und in den Stream schreiben */
                    if (output_stream.write (frame_data[bytes_sent: (bytes_sent + next_size)]) != next_size) {
                        warning ("Fehler beim Senden eines UDP-Paketes.");
                    }
                }
            } catch (Error e) {
                warning ("Senden des Frames fehlgeschlagen: %s", e.message);
            }
        });

        camera.start ();
    }
}