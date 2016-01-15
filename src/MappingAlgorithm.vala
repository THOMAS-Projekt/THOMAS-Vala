/*
 * Copyright (c) 2011-2016 THOMAS-Projekt (https://thomas-projekt.de)
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
 *
 * Authored by: Marcus Wichelmann <marcus.wichelmann@hotmail.de>
 */

/*
 * Stellt den Algorithmus zur Autonomen Kartierung der Umgebung dar.
 * Dieser Klasse müssen im Konstruktor einige Funktionen zur Kontrolle des Roboters übergeben werden,
 * die als Schnittstelle dienen. Ereignisse und Fortschritte werden der Klasse über die jeweiligen
 * "handle"-Funktionen mitgeteilt.
 *
 * Dieser Algorithmus wurde im Rahmen der Facharbeit von Marcus Wichelmann entwickelt und dokumentiert.
 */
public class THOMAS.MappingAlgorithm : Object {
    /* Der maximale erlaubte Abstand zwischen den Auftrittspunkten der Messwerte, damit eine Wand erkannt wird */
    private static const int WALL_MAX_DISTANCE_GAP = 60;

    /* Die maximale erlaubte Richtungsdifferenz zwischen den Auftrittspunkten der Messwerte, damit eine Wand erkannt wird */
    private static const double WALL_MAX_DIRECTION_GAP = (Math.PI / 180) * 40;

    /* Startwinkel des rechtsliegenden Bereiches */
    private static const double RIGHT_AREA_START_ANGLE = (Math.PI / 180) * 120;

    /* Endwinkel des rechtsliegenden Bereiches */
    private static const double RIGHT_AREA_END_ANGLE = (Math.PI / 180) * 180;

    /* Der Maximale Abstand einer rechtsliegenden Wand zum Roboter */
    private static const uint16 RIGHT_WALL_MAX_DISTANCE = 100;

    /* Mindestlänge der Summe der rechtsliegenden Wände zur Überprüfung der Aussagekräftigkeit */
    private static const int MIN_RIGHT_WALL_LENGTH_SUM = 20;

    /* Die Zeit für die die Motoren für eine Richtungskorrektur eingeschaltet werden */
    private static const uint STEP_TURNING_TIME = 1500;

    /* Die Zeit für die die Motoren für einen Schritt nach vorne eingeschaltet werden */
    private static const uint STEP_MOVING_TIME = 1000;

    /* Konvertiert Grad in Bogemmaß */
    private static double deg_to_rad (uint8 degree) {
        return ((Math.PI / 180) * degree);
    }

    /* Berechnet den Durschnittswert aus einem Array aus Fließkommazahlen */
    private static double double_avg (double[] values) {
        /* Teilung durch null verhindern */
        if (values.length == 0) {
            return 0;
        }

        /* Die Summe aller Fließkommazahlen */
        double sum = 0;

        /* Alle Zahlen aufaddieren */
        foreach (double @value in values) {
            sum += @value;
        }

        /* Durchschnittswert berechnen */
        return sum / values.length;
    }

    /* Sucht in den Messwerten nach regelmäßigkeiten und interpretiert diese als Wände */
    private static Wall[] detect_walls (Gee.TreeMap<double? , uint16> distances) {
        /* Liste der erkannten Wände */
        Wall[] walls = {};

        /* Der Winkel des Startpunktes der Wand */
        double wall_start_angle = -1;

        /* Die Koordinaten des Startpunktes der Wand */
        int wall_start_position_x = 0;
        int wall_start_position_y = 0;

        /* Der letzte überprüfte Winkel */
        double last_angle = -1;

        /* Der Distanzwert zum letzten überprüften Winkel */
        uint16 last_distance = 0;

        /* Die Koordinaten des letzten überprüften Messwertes */
        int last_position_x = 0;
        int last_position_y = 0;

        /* Liste der letzten Wandrichtungen */
        double[] last_directions = {};

        /* Alle Messwerte durchlaufen */
        distances.@foreach ((entry) => {
            /* Infos zum Messwert abrufen */
            double angle = entry.key;
            uint16 distance = entry.@value;

            /* Auftrittspunkt des Messwertes bestimmen */
            int position_x = (int)(-Math.sin (angle - (Math.PI / 2)) * distance);
            int position_y = (int)(Math.cos (angle - (Math.PI / 2)) * distance);

            /* Prüfen, ob dies der erste Messwert ist */
            if (last_angle >= 0) {
                /* Den Abstand zu den Koordinaten des letzten Auftrittspunktes berechnen */
                int distance_gap = (int)(Math.sqrt (Math.pow (position_x - last_position_x, 2) + Math.pow (position_y - last_position_y, 2)));

                /* Bewegt sich der Abstand innerhalb der Parameter? */
                if (distance_gap < WALL_MAX_DISTANCE_GAP) {
                    /* Wurde bereits eine Wand begonnen? */
                    if (wall_start_angle < 0) {
                        /* Startwinkel der neuen Wand merken */
                        wall_start_angle = last_angle;

                        /* Startkoordinaten der neuen Wand merken */
                        wall_start_position_x = last_position_x;
                        wall_start_position_y = last_position_y;
                    } else {
                        /* Wurde bereits ein paar vorherige Wandrichtungen erfasst? */
                        if (last_directions.length > 2) {
                            /* Wandrichtung bezogen auf den vorherigen Punkt bestimmen */
                            double direction = Math.atan ((double)(position_y - last_position_y) / (double)(position_x - last_position_x));

                            /* Durchschnittswert der vorherigen paar Wandrichtungen berechnen */
                            double avg_direction = double_avg (last_directions[(last_directions.length > 8 ? last_directions.length - 8 : 0) : last_directions.length - 2]);

                            /* Falls die vorherige Wandrichtung bekannt ist, Differenz überprüfen */
                            if (Math.fabs (direction - avg_direction) > WALL_MAX_DIRECTION_GAP) {
                                /* Länge der Wand mit dem Satz des Pythagoras berechnen */
                                int wall_length = (int)(Math.sqrt (Math.pow (last_position_x - wall_start_position_x, 2) + Math.pow (last_position_y - wall_start_position_y, 2)));

                                /* Neue Struktur, die die Wand beschreibt, anlegen */
                                Wall wall = { wall_start_angle,
                                              wall_start_position_x,
                                              wall_start_position_y,
                                              last_angle,
                                              last_position_x,
                                              last_position_y,
                                              last_distance,
                                              wall_length,
                                              last_directions[last_directions.length - 1] };

                                /* Wand zur Liste hinzufügen */
                                walls += wall;

                                /* Die Wand ist hier zu Ende */
                                wall_start_angle = -1;

                                /* Liste der Wandrichtungen zurücksetzen */
                                last_directions = {};
                            } else {
                                /* Richtung merken */
                                last_directions += direction;
                            }
                        } else {
                            /* Richtung bezogen auf den Startpunkt merken */
                            last_directions += Math.atan ((double)(position_y - wall_start_position_y) / (double)(position_x - wall_start_position_x));
                        }
                    }
                } else {
                    /* Wurde bereits eine Wand begonnen? */
                    if (wall_start_angle >= 0) {
                        /* Länge der Wand mit dem Satz des Pythagoras berechnen */
                        int wall_length = (int)(Math.sqrt (Math.pow (last_position_x - wall_start_position_x, 2) + Math.pow (last_position_y - wall_start_position_y, 2)));

                        /* Die letzte Richtung */
                        double last_direction;

                        /* Prüfen, ob die letze Richtung aus der Richtungsliste abgerufen werden kann */
                        if (last_directions.length > 0) {
                            /* Richtung aus Liste auslesen */
                            last_direction = last_directions[last_directions.length - 1];
                        } else {
                            if (last_position_x == wall_start_position_x) {
                                /* Richtung anhand der aktuellen Position bestimmen */
                                last_direction = Math.atan ((double)(position_y - wall_start_position_y) / (double)(position_x - wall_start_position_x));
                            } else {
                                /* Richtung anhand der letzten Position bestimmen */
                                last_direction = Math.atan ((double)(last_position_y - wall_start_position_y) / (double)(last_position_x - wall_start_position_x));
                            }
                        }

                        /* Neue Struktur, die die Wand beschreibt, anlegen */
                        Wall wall = { wall_start_angle,
                                      wall_start_position_x,
                                      wall_start_position_y,
                                      last_angle,
                                      last_position_x,
                                      last_position_y,
                                      last_distance,
                                      wall_length,
                                      last_direction };

                        /* Wand zur Liste hinzufügen */
                        walls += wall;
                    }

                    /* Dies ist kein Startpunkt einer neuen Wand*/
                    wall_start_angle = -1;
                }
            }

            /* Winkel merken */
            last_angle = angle;

            /* Distanz merken */
            last_distance = distance;

            /* Koordinaten merken */
            last_position_x = position_x;
            last_position_y = position_y;

            /* Messwerte weiter durchlaufen */
            return true;
        });

        /* Wurde die letzte Wand schon beendet? */
        if (wall_start_angle >= 0) {
            /* Länge der Wand mit dem Satz des Pythagoras berechnen */
            int wall_length = (int)(Math.sqrt (Math.pow (last_position_x - wall_start_position_x, 2) + Math.pow (last_position_y - wall_start_position_y, 2)));

            /* Die letzte Richtung */
            double last_direction;

            /* Prüfen, ob die letze Richtung aus der Richtungsliste abgerufen werden kann */
            if (last_directions.length > 0) {
                /* Richtung aus Liste auslesen */
                last_direction = last_directions[last_directions.length - 1];
            } else {
                /* Die Wand ist dann wohl ohnehin äußerst kurz, die können wir einfach ignorieren */
                return walls;
            }

            /* Neue Struktur, die die Wand beschreibt, anlegen */
            Wall wall = { wall_start_angle,
                          wall_start_position_x,
                          wall_start_position_y,
                          last_angle,
                          last_position_x,
                          last_position_y,
                          last_distance,
                          wall_length,
                          last_direction };

            /* Wand zur Liste hinzufügen */
            walls += wall;
        }

        /* Liste der Wände zurückgeben */
        return walls;
    }

    /* Versucht aus den erkannten Wänden eine Wand rechts vom Roboter zu bilden und gibt diese ggf. zurück */
    private static double? search_for_right_wall (Wall[] walls) {
        /* Liste der rausgefilterten Wände */
        Wall[] right_walls = {};

        /* Summe der Längen der rausgefilterten Wände */
        int wall_length_sum = 0;

        /* Summe der Richtungen der rausgefilterten Wände */
        double relative_direction_sum = 0;

        /* Alle Wände durchlaufen */
        foreach (Wall wall in walls) {
            /* Wir gehen davon aus, dass Wände mit einem niedrigen Winkel beginnen und mit einem hohen enden. */
            assert (wall.start_angle < wall.end_angle);

            /* Überprüfen, ob die Wand nahe rechts vom Roboter liegt */
            if (wall.start_angle >= RIGHT_AREA_START_ANGLE && wall.end_angle <= RIGHT_AREA_END_ANGLE && wall.distance <= RIGHT_WALL_MAX_DISTANCE) {
                /* Wand zur Liste der rechtsliegenden Wände aufnehmen */
                right_walls += wall;

                /* Summen ergänzen */
                wall_length_sum += wall.wall_length;
                relative_direction_sum += wall.relative_direction;
            }
        }

        /* Es sollten mindestens zwei Wände erkannt worden sein */
        if (right_walls.length < 2) {
            return null;
        }

        /* Prüfen, ob die Länge der rechts erkannten Wände aussagekräftig ist */
        if (wall_length_sum < MIN_RIGHT_WALL_LENGTH_SUM) {
            return null;
        }

        /* Erste und letze Wand abfragen */
        Wall first_right_wall = right_walls[0];
        Wall last_right_wall = right_walls[right_walls.length - 1];

        /* Teilen durch null verhindern */
        if (last_right_wall.relative_end_x == first_right_wall.relative_start_x) {
            /* Entspricht relativ gesehen der Richtung des Roboters */
            return 0;
        }

        /* Richtung der Wand berechnen und zurückgeben*/
        return Math.atan ((double)(last_right_wall.relative_end_y - first_right_wall.relative_start_y) / (double)(last_right_wall.relative_end_x - first_right_wall.relative_start_x));
    }

    /* Stellt eine automatisch erkannte Wand dar */
    public struct Wall {
        /* Winkel des Startpunktes im Messbereich des Roboters */
        double start_angle;

        /* Relative Koordinaten des Startpunktes */
        int relative_start_x;
        int relative_start_y;

        /* Winkel des Endpunktes im Messbereich des Roboters */
        double end_angle;

        /* Relative Koordinaten des Enpunktes */
        int relative_end_x;
        int relative_end_y;

        /* Die Distanz der Wand zum Roboter */
        uint16 distance;

        /* Länge der wand */
        int wall_length;

        /* Relative Richtung der Wand (bezogen auf die Drehrichtung des Roboters) */
        double relative_direction;
    }

    /* Spiegelt die Funktionen zum Steuern des Roboters wieder */
    public delegate void MoveFunc (short speed, uint duration);
    public delegate void TurnFunc (short speed, uint duration);
    public delegate int StartNewScanFunc ();

    /* Zeigt auf eine Funktion zum Einleiten einer definierten Vorwärts- oder Rückwärtsbewegung */
    public unowned MoveFunc move { private get; private set; }

    /* Zeigt auf eine Funktion zum Auführen einer Drehung */
    public unowned TurnFunc turn { private get; private set; }

    /* Zeit auf eine Funktion zum Beginn eines neuen Scanvorganges */
    public unowned StartNewScanFunc start_new_scan { private get; private set; }

    /* Zuletzt erkannte Wandliste */
    public Wall[]? last_detected_walls { get; private set; default = null; }

    /* Speichert die Distanzwerte des momentanen Scanvorganges */
    private Gee.TreeMap<double? , uint16> current_scan;

    /* Der Konstruktor der Klasse, hier sollten die nötigen Funktionen zur Kontrolle des Roboters übergeben werden */
    public MappingAlgorithm (MoveFunc move_func, TurnFunc turn_func, StartNewScanFunc start_new_scan_func) {
        /* Funktionen global zuweisen */
        this.move = move_func;
        this.turn = turn_func;
        this.start_new_scan = start_new_scan_func;

        /* Erste Messreihe beginnen */
        current_scan = new Gee.TreeMap<double? , uint16> ();

        /* Zunächst einmal die momentane Umgebung scannen */
        start_new_scan ();
    }

    /* Sollte aufgerufen werden, wenn eine weitere durchschnittliche Distanz einer Karte erfasst wurde */
    public void handle_map_scan_continued (int map_id, uint8 angle, uint16 avg_distance) {
        /* Wir setzen hier vorraus, dass immer nur eine Map gleichzeitig aufgenommen wird. */

        /*
         * Distanzwert zum Scan hinzufügen
         * Winkel werden im weiteren Verlauf als Bogenmaß verwendet, daher schon hier konvertieren
         */
        current_scan.@set (deg_to_rad (angle), avg_distance);
    }

    /* Sollte aufgerufen werden, wenn der Scanvorgang einer Karte abgeschlossen wurde */
    public void handle_map_scan_finished (int map_id) {
        /* Wände anhand der Messdaten detektieren */
        Wall[] walls = detect_walls (current_scan);

        /* Wände speichern, damit sie extern abgerufen werden können */
        last_detected_walls = walls;

        /* Nach einer Wand auf der rechten Seite des Roboters suchen. */
        double? right_wall_direction = search_for_right_wall (walls);

        /* Wurde eine Wand gefunden? */
        if (right_wall_direction != null) {
            /* Anhand dieser Wand neu ausrichten */
            turn ((short)(right_wall_direction * -100), STEP_TURNING_TIME);

            /* Bis zum Ende der Neuausrichtung abwarten */
            Timeout.add (STEP_TURNING_TIME, () => {
                /* Forwärtsbewegung */
                move (200, STEP_MOVING_TIME);

                /* Dies ist keine Schleife */
                return false;
            });
        } else {
            /* Forwärtsbewegung */
            move (150, STEP_MOVING_TIME);
        }

        /* Neue Messreihe beginnen */
        current_scan = new Gee.TreeMap<double? , uint16> ();

        /* Bis zum Ende der Neuausrichtung abwarten */
        Timeout.add (STEP_MOVING_TIME + (right_wall_direction != null ? STEP_TURNING_TIME : 0), () => {
            /* Neuen Scanvorgang einleiten */
            start_new_scan ();

            /* Dies ist keine Schleife */
            return false;
        });
    }
}