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

public class THOMAS.Logger : Object {
    private bool debug_mode = false;

    public Logger () {
        /* Sprache setzen, damit Umlaute korrekt dargestellt werden */
        Intl.setlocale (LocaleCategory.ALL, "de_DE.UTF-8");

        /* GLibs Log-Handler überschreiben */
        Log.set_default_handler (log_handler);

        warning ("Ich bin eine\nNachricht mit nem Tollen\nZeilenumbruch.... :P");
    }

    public void set_debug_mode (bool debug_mode) {
        this.debug_mode = debug_mode;
    }

    private void log_handler (string? log_domain, LogLevelFlags log_levels, string message) {
        if (!debug_mode && log_levels == LogLevelFlags.LEVEL_DEBUG) {
            return;
        }

        string[] lines = message.split ("\n");
        int header_length = 0;

        for (int i = 0; i < lines.length; i++) {
            /* chug () löscht Leerzeichen am Anfang des Strings. */
            string line = lines[i].chug ();

            if (i == 0) {
                header_length = print_header (log_levels);
            } else {
                print_indentation (header_length);
            }

            stdout.printf ("%s\n", message);
        }
    }

    private int print_header (LogLevelFlags log_levels) {
        string level;
        int color_code = 30 + 60;

        switch (log_levels) {
            case LogLevelFlags.LEVEL_ERROR :
                level = "FEHLER";

                /* Rot */
                color_code += 1;

                break;

            case LogLevelFlags.LEVEL_INFO:
            case LogLevelFlags.LEVEL_MESSAGE:
                level = "INFO";

                /* Blau */
                color_code += 4;

                break;

            case LogLevelFlags.LEVEL_DEBUG:
                level = "DEBUG";

                /* Grün */
                color_code += 2;

                break;

            case LogLevelFlags.LEVEL_WARNING:
            default:
                level = "WARNUNG";

                /* Gelb */
                color_code += 3;

                break;
        }

        string time = "asdf";

        stdout.printf ("\x001b[%dm[%s %s]\x001b[0m ", color_code, level, time);

        return (level.length + time.length + 4);
    }

    private void print_indentation (int lenght) {
        //char[] indentation = {' '};
    }
}