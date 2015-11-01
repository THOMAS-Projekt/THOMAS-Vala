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

    /* Konstante, definiert die maximale Geschwindigkeitsänderung pro Motorsteuerungstakt. */
    const short speedMaxAcc = 15;

    private uint accelerate_timer_id = 0;

    private short[] current_speed;

    public enum Motor {
        MRIGHT = 1,
        MLEFT = 2,
        MBOTH = 3,
        MLEFT_ARR = 0,
        MRIGHT_ARR = 1
    }

    public MotorControl (string tty_name) {
        base (tty_name, BAUDRATE);
        base.attach((termios) => {
            /* Baudrate setzen */
            termios.c_ispeed = baudrate;
            termios.c_ospeed = baudrate;

            /* Neue Konfiguration zurückgeben */
            return termios;
        });

        current_speed = { 0, 0 };
    }

    public void set_motor_speed (Motor motor, short speed) {
        base.send_package ({ 35, 35, 6, 5, (uint8)motor, (uint8)(speed > 0) }, false);

        base.send_package ({ 35, 35, 6, 2, (uint8)motor, (uint8)speed.abs () }, false);
    }

    public void accerlerate_to_motor_speed (Motor motor, short[] wanted_speed) {
        if (accelerate_timer_id != 0) {
            Source.remove (accelerate_timer_id);
        }

        accelerate_timer_id = Timeout.add (100, () => {
            set_motor_speed (Motor.MLEFT, current_speed[Motor.MLEFT_ARR] + (wanted_speed[Motor.MLEFT_ARR] > current_speed[Motor.MLEFT_ARR] ? speedMaxAcc : -speedMaxAcc));

            set_motor_speed (Motor.MRIGHT, current_speed[Motor.MRIGHT_ARR] + (wanted_speed[Motor.MRIGHT_ARR] > current_speed[Motor.MRIGHT_ARR] ? speedMaxAcc : -speedMaxAcc));

            return true;
        });
    }
}