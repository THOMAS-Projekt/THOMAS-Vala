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

public class THOMAS.Camera : Object {
    private static const int CAMERA_FRAME_WIDTH = 1280;
    private static const int CAMERA_FRAME_HEIGHT = 720;

    public signal void frame_captured (Gdk.Pixbuf frame);

    public Gdk.Pixbuf? last_frame { get; private set; default = null; }

    private OpenCV.Capture capture;

    /* Zählt die Objekte die auf */
    private int access_counter = 0;

    public Camera (int camera_id) {
        capture = new OpenCV.Capture.from_camera (camera_id);
        capture.set_property (OpenCV.Capture.Property.FRAME_WIDTH, CAMERA_FRAME_WIDTH);
        capture.set_property (OpenCV.Capture.Property.FRAME_HEIGHT, CAMERA_FRAME_HEIGHT);
    }

    ~Camera () {
        access_counter = 0;
        debug ("Bildaufnahme gestoppt.");
    }

    public void start () {
        if (access_counter < 0) {
            access_counter = 0;
        }

        if (access_counter++ > 0) {
            return;
        }

        new Thread<int> (null, () => {
            while (access_counter > 0) {
                query_frame ();
            }

            debug ("Bildaufnahme gestoppt.");

            return 0;
        });

        debug ("Bildaufnahme gestartet.");
    }

    public void stop () {
        if (access_counter-- <= 0) {
            access_counter = 0;
        }
    }

    private void query_frame () {
        /* Frame aufnehmen */
        unowned OpenCV.IPL.Image raw_frame = capture.query_frame ();

        /* Bild in RGB-Farbraum konvertieren */
        raw_frame.convert_color (raw_frame, 4);

        /* Bild in Gdk.Pixbuf konvertieren. */
        Gdk.Pixbuf frame = new Gdk.Pixbuf.from_data (raw_frame.image_data,
                                                     Gdk.Colorspace.RGB,
                                                     false,
                                                     raw_frame.depth,
                                                     raw_frame.width,
                                                     raw_frame.height,
                                                     raw_frame.width_step);

        last_frame = frame;

        frame_captured (frame);
    }
}