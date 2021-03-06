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

public class THOMAS.MotorControl : SerialDevice {
    private static const uint BAUDRATE = Posix.B9600;

    /* Definiert die maximale Geschwindigkeitsänderung pro 100ms. */
    private static const short MAX_ACCELERATION = 15;

    /* Die Motor-IDs die die Positionen der Werte im Geschwindigkeitsarray angeben */
    private static const int MOTOR_LEFT_ID = 0;
    private static const int MOTOR_RIGHT_ID = 1;

    public enum Motor {
        LEFT = 2,
        RIGHT = 1,
        BOTH = 3;

        public static Motor from_number (int number) {
            switch (number) {
                case 2: return Motor.LEFT;
                case 1: return Motor.RIGHT;
                default:
                case 3: return Motor.BOTH;
            }
        }

        public static Motor from_name (string name) {
            switch (name.down ()) {
                case "left": return Motor.LEFT;
                case "right": return Motor.RIGHT;
                default:
                case "both": return Motor.BOTH;
            }
        }
    }

    private uint accelerate_timer_id = 0;

    /* Die momentane Geschwindigkeit */
    private short[] current_speed;

    /* Die Zielgeschwindigkeit */
    private short[] wanted_speed;

    /* Timer der die Zeit zwischen Neuberechnungen zählt */
    private Timer last_recalculation_timer;

    public MotorControl (string tty_name) {
        base (tty_name, BAUDRATE);
        base.attach ((termios) => {
            /* Konfiguration unverändert zurückgeben */
            return termios;
        });

        /* Ausgangsgeschwindigkeit */
        current_speed = { 0, 0 };
        wanted_speed = { 0, 0 };

        /* Neuberechnungs-Timer erstellen */
        last_recalculation_timer = new Timer ();
        last_recalculation_timer.start ();
    }

    public void setup () {
        new Thread<int> (null, () => {
            while (true) {
                update_motor (Motor.LEFT, MOTOR_LEFT_ID);
                update_motor (Motor.RIGHT, MOTOR_RIGHT_ID);

                Thread.usleep (100 * 1000);
            }
        });
    }

    public void set_motor_speed (Motor motor, short speed) {
        /* Geschwindigkeitswerte des linken Motors aktualisieren */
        if (motor == Motor.LEFT || motor == Motor.BOTH) {
            current_speed[MOTOR_LEFT_ID] = wanted_speed[MOTOR_LEFT_ID] = (speed > 255 ? 255 : speed < -255 ? -255 : speed);
        }

        /* Geschwindigkeitswerte des rechten Motors aktualisieren */
        if (motor == Motor.RIGHT || motor == Motor.BOTH) {
            current_speed[MOTOR_RIGHT_ID] = wanted_speed[MOTOR_RIGHT_ID] = (speed > 255 ? 255 : speed < -255 ? -255 : speed);
        }
    }

    public void accelerate_to_motor_speed (Motor motor, short speed) {
        /* Bereits laufende Beschleunigungen abbrechen */
        if (accelerate_timer_id != 0) {
            Source.remove (accelerate_timer_id);
        }

        /* Zielgeschwindigkeit des linken Motors setzen */
        if (motor == Motor.LEFT || motor == Motor.BOTH) {
            wanted_speed[MOTOR_LEFT_ID] = (speed > 255 ? 255 : speed < -255 ? -255 : speed);
        }

        /* Zielgeschwindigkeit des rechten Motors setzen */
        if (motor == Motor.RIGHT || motor == Motor.BOTH) {
            wanted_speed[MOTOR_RIGHT_ID] = (speed > 255 ? 255 : speed < -255 ? -255 : speed);
        }

        /* Beschleunigung initialisieren */
        recalculate_motor_speed ();

        /* Neue Beschleunigung beginnen */
        accelerate_timer_id = Timeout.add (100, recalculate_motor_speed);
    }

    private bool recalculate_motor_speed () {
        if (last_recalculation_timer.elapsed () < 0.09) {
            return true;
        }

        last_recalculation_timer.start ();

        /* Ausstehende Geschwindigkeitsänderungen bestimmen */
        short pending_difference_left = (wanted_speed[MOTOR_LEFT_ID] - current_speed[MOTOR_LEFT_ID]).abs ();
        short pending_difference_right = (wanted_speed[MOTOR_RIGHT_ID] - current_speed[MOTOR_RIGHT_ID]).abs ();

        if (pending_difference_left > 0) {
            /* Vorzeichen bestimmen */
            short acceleration_sign = (wanted_speed[MOTOR_LEFT_ID] > current_speed[MOTOR_LEFT_ID] ? 1 : -1);

            /* Geschwindigkeit entweder um Differenz, oder um Maximalbeschleunigung erhöhen */
            current_speed[MOTOR_LEFT_ID] += (pending_difference_left > MAX_ACCELERATION ? MAX_ACCELERATION : pending_difference_left) * acceleration_sign;
        }

        if (pending_difference_right > 0) {
            /* Vorzeichen bestimmen */
            short acceleration_sign = (wanted_speed[MOTOR_RIGHT_ID] > current_speed[MOTOR_RIGHT_ID] ? 1 : -1);

            /* Geschwindigkeit entweder um Differenz, oder um Maximalbeschleunigung erhöhen */
            current_speed[MOTOR_RIGHT_ID] += (pending_difference_right > MAX_ACCELERATION ? MAX_ACCELERATION : pending_difference_right) * acceleration_sign;
        }

        /* Prüfen ob der Timer weiterlaufen soll. */
        if (pending_difference_left > 0 || pending_difference_right > 0) {
            /* Weiter beschleunigen */
            return true;
        } else {
            /* Beschleunigung abgeschlossen. */
            accelerate_timer_id = 0;

            return false;
        }
    }

    private void update_motor (Motor motor, int motor_id) {
        /* Drehrichtung senden */
        base.send_package ({ 35, 35, 3, 5, (uint8)motor, (uint8)(current_speed[motor_id] >= 0) }, false);

        /* Geschwindigkeit senden */
        base.send_package ({ 35, 35, 3, 2, (uint8)motor, (uint8)current_speed[motor_id].abs () }, false);
    }
}