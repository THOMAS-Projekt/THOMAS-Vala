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
    private static const uint BAUDRATE = 9600;

    /* Definiert die maximale Geschwindigkeitsänderung pro 100ms. */
    private static const short MAX_ACCELERATION = 15;

    /* Die Motor-IDs die die Positionen der Werte im Geschwindigkeitsarray angeben */
    private static const int MOTOR_LEFT_ID = 0;
    private static const int MOTOR_RIGHT_ID = 1;

    public enum Motor {
        LEFT = 2,
        RIGHT = 1,
        BOTH = 3
    }

    private uint accelerate_timer_id = 0;

    /* Die momentane Geschwindigkeit */
    private short[] current_speed;

    /* Die Zielgeschwindigkeit */
    private short[] wanted_speed;

    public MotorControl (string tty_name) {
        base (tty_name, BAUDRATE);
        base.attach ((termios) => {
            /* Baudrate setzen */
            termios.c_ispeed = BAUDRATE;
            termios.c_ospeed = BAUDRATE;

            /* Neue Konfiguration zurückgeben */
            return termios;
        });

        /* Ausgangsgeschwindigkeit */
        current_speed = { 0, 0 };
    }

    public void set_motor_speed (Motor motor, short speed) {
        /* Geschwindigkeitswerte des linken Motors aktualisieren */
        if (motor == Motor.LEFT || motor == Motor.BOTH) {
            current_speed[MOTOR_LEFT_ID] = wanted_speed[MOTOR_LEFT_ID] = speed;
        }

        /* Geschwindigkeitswerte des rechten Motors aktualisieren */
        if (motor == Motor.RIGHT || motor == Motor.BOTH) {
            current_speed[MOTOR_RIGHT_ID] = wanted_speed[MOTOR_RIGHT_ID] = speed;
        }

        /* Drehrichtung senden */
        base.send_package ({ 35, 35, 6, 5, (uint8)motor, (uint8)(speed >= 0) }, false);

        /* Geschwindigkeit senden */
        base.send_package ({ 35, 35, 6, 2, (uint8)motor, (uint8)speed.abs () }, false);
    }

    public void accelerate_to_motor_speed (Motor motor, short speed) {
        /* Bereits laufende Beschleunigungen abbrechen */
        if (accelerate_timer_id != 0) {
            Source.remove (accelerate_timer_id);
        }

        /* Zielgeschwindigkeit des linken Motors setzen */
        if (motor == Motor.LEFT || motor == Motor.BOTH) {
            wanted_speed[MOTOR_LEFT_ID] = speed;
        }

        /* Zielgeschwindigkeit des rechten Motors setzen */
        if (motor == Motor.RIGHT || motor == Motor.BOTH) {
            wanted_speed[MOTOR_RIGHT_ID] = speed;
        }

        /* Neue Beschleunigung beginnen */
        accelerate_timer_id = Timeout.add (100, () => {
            bool speed_reached = true;

            if (current_speed[MOTOR_LEFT_ID] < wanted_speed[MOTOR_LEFT_ID]) {
                /* Geschwindigkeit schrittweise erhöhen */
                set_motor_speed (Motor.LEFT, current_speed[MOTOR_LEFT_ID] + (wanted_speed[MOTOR_LEFT_ID] > current_speed[MOTOR_LEFT_ID] ? MAX_ACCELERATION : -MAX_ACCELERATION));

                /* Es war noch eine Geschwindigkeitsänderung nötig. */
                speed_reached = false;
            }

            if (current_speed[MOTOR_RIGHT_ID] < wanted_speed[MOTOR_RIGHT_ID]) {
                /* Geschwindigkeit schrittweise erhöhen */
                set_motor_speed (Motor.RIGHT, current_speed[MOTOR_RIGHT_ID] + (wanted_speed[MOTOR_RIGHT_ID] > current_speed[MOTOR_RIGHT_ID] ? MAX_ACCELERATION : -MAX_ACCELERATION));

                /* Es war noch eine Geschwindigkeitsänderung nötig. */
                speed_reached = false;
            }

            /* Prüfen ob der Timer weiterlaufen soll. */
            return !speed_reached;
        });
    }
}