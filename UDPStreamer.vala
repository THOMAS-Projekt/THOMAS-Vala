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
    private OpenCV.Capture camera;

    public UDPStreamer (int camera_id) {
        camera = new OpenCV.Capture.from_camera (camera_id);
        camera.set_property (OpenCV.Capture.Property.FRAME_WIDTH, 1280);
        camera.set_property (OpenCV.Capture.Property.FRAME_HEIGHT, 720);
    }

    public void setup () {
        OpenCV.Window.create_named ("bla");

        new Thread<int> (null, () => {
            while (true) {
                unowned OpenCV.IPL.Image frame = camera.query_frame ();
                OpenCV.Window.show_image ("bla", frame);
            }
        });
    }
}