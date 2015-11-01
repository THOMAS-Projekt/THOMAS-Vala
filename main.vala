/*
 * Copyright (c) 2011-2015 THOMAS Developers (https://thomas-projekt.de)
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
        { "arduinotty", 'a', 0, OptionArg.STRING, ref arduino_tty, "Port des Arduinos", "PORT" },
        { "enable-minimalmode", 'm', 0, OptionArg.NONE, ref enable_minimalmode, "Aktiviert den Minimalmodus des Arduinos", null },
        { null }
    };

    private static string? arduino_tty = null;

    private static string? enable_minimalmode = null;

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

    public Main () {
        var arduino = new Arduino (arduino_tty == null ? "/dev/ttyACM0" : arduino_tty);
        
        arduino.wait_for_initialisation ();

        debug ("Arduino gestartet.");

        arduino.setup (enable_minimalmode == null ? false : true);

        new MainLoop ().run ();
    }
}