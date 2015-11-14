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

public class THOMAS.DistanceMap : Object {
    private static const uint8 SMALL_SENSOR_MEASUREMENT_COUNT = 10;
    private static const uint8 LARGE_SENSOR_MEASUREMENT_COUNT = 10;

    public Arduino arduino { private get; construct; }

    public DistanceMap (Arduino arduino) {
        Object (arduino: arduino);
    }

    public void setup () {
        uint8 current_angle = 5;

        Timeout.add (100, () => {
            debug (current_angle.to_string ());
            arduino.do_distance_measurement (current_angle+=2, SMALL_SENSOR_MEASUREMENT_COUNT, LARGE_SENSOR_MEASUREMENT_COUNT);

            return (current_angle < 180);
        });
    }
}