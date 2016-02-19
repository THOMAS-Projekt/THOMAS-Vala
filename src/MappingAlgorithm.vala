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
    /* Klasse mit einigen Hilfsfunktionen zur Darstellung einer Karte mit unbekannten Ausmaßen in alle vier Richtungen */
    public class Map {
        /* Die Größe eines Feldes in cm. */
        private static const int FIELD_SIZE = 10;

        /* Die ungefähre Größe des Roboters in cm. */
        private static const int ROBOT_SIZE = 60;

        /* Eine Struktur, die die Koordinate eines Feldes enthält */
        public struct Field {
            int x;
            int y;
            FieldState state;
        }

        /* Die drei verschiedene Zustände eines Feldes der Karte */
        public enum FieldState {
            UNKNOWN,
            FREE,
            WALL
        }

        /* Die Ausmaßen der Karte */
        public int min_x { get; private set; default = 0; }
        public int max_x { get; private set; default = 0; }
        public int min_y { get; private set; default = 0; }
        public int max_y { get; private set; default = 0; }

        /*
         * Das Koordinatensystem
         * FIXME: Die Verwendung einer ArrayList stellt hier einen Workaround für einen Fehler in mehrdimensionalen Arrays dar.
         * Siehe https://bugzilla.gnome.org/show_bug.cgi?id=735159
         */
        public Gee.ArrayList<Field? > map { get; private set; }

        /* Erstellt eine neue Umgebungskarte */
        public Map () {
            /* Koordinatenliste erstellen */
            map = new Gee.ArrayList<Field? > ();
        }

        /* Setzt den Zustand eines Feldes */
        public void set_field_state (int x, int y, FieldState state, FieldState? previous_state = null) {
            /* Vorherige Felder mit gleicher Position löschen */
            foreach (Field field in map) {
                /* Ist dies der gesuchte Eintrag? */
                if (field.x == x && field.y == y) {
                    /* Wird ein vorheriger Zustand erwartet? */
                    if (previous_state != null && field.state != previous_state) {
                        /* Dieser Eintrag sollte nicht gesetzt werden */
                        return;
                    }

                    /* Eintrag löschen */
                    map.remove (field);

                    /* Suche beenden */
                    break;
                }
            }

            /* Zustand speichern */
            map.add ({ x, y, state });

            /* Ausmaßen aktualisieren */
            min_x = (x < min_x ? x : min_x);
            max_x = (x > max_x ? x : max_x);
            min_y = (y < min_y ? y : min_y);
            max_y = (y > max_y ? y : max_y);
        }

        /* Ruft den Zustand eines Feldes ab */
        public FieldState get_field_state (int x, int y) {
            /* Der gefundene Zustand */
            FieldState state = FieldState.UNKNOWN;

            /* FIXME: Da ein direkter Vergleich der Structs nicht möglich ist, muss manuell in der Liste gesucht werden */
            foreach (Field field in map) {
                /* Ist dies der gesuchte Eintrag? */
                if (field.x == x && field.y == y) {
                    /* Zustand auslesen */
                    state = field.state;

                    /* Suche beenden */
                    break;
                }
            }

            /* Zustand zurückgeben */
            return state;
        }

        /* Belegt alle Felder entlang einer Wand augeghend von der Roboterposition */
        public void set_wall_fields (int position_x, int position_y, double direction, Wall wall) {
            /* Absolute Koordinaten der Start- und Endpunkte der Wand auf der Karte bestimmen */
            int wall_start_x = (int)(position_x + (Math.cos (direction) * wall.relative_start_x - (Math.sin (direction) * wall.relative_start_y)));
            int wall_start_y = (int)(position_y + (Math.cos (direction) * wall.relative_start_y + (Math.sin (direction) * wall.relative_start_x)));
            int wall_end_x = (int)(position_x + (Math.cos (direction) * wall.relative_end_x - (Math.sin (direction) * wall.relative_end_y)));
            int wall_end_y = (int)(position_y + (Math.cos (direction) * wall.relative_end_y + (Math.sin (direction) * wall.relative_end_x)));

            /* Prüfen, an welcher Achse man sich orientieren sollte */
            if (wall_start_x != wall_end_x) {
                /* Inkrementor in y-Richtung pro Schritt auf der x-Achse bestimmen */
                double incrementor = (wall_start_y - wall_end_y) / (wall_start_x - wall_end_x);

                /* x-Achse entlanglaufen */
                for (double x = (wall_start_x < wall_end_x ? wall_start_x : wall_end_x); x < (wall_start_x < wall_end_x ? wall_end_x : wall_start_x); x++) {
                    /* y-Koordinate bestimmen */
                    double y = (wall_start_x < wall_end_x ? wall_start_y : wall_end_y) + (incrementor * (x - (wall_start_x < wall_end_x ? wall_start_x : wall_end_x)));

                    /* Zustand des Feldes setzen */
                    set_field_state ((int)(x / FIELD_SIZE), (int)(y / FIELD_SIZE), FieldState.WALL, Map.FieldState.UNKNOWN);
                }
            } else if (wall_start_y != wall_end_y) {
                /* Inkrementor in x-Richtung pro Schritt auf der y-Achse bestimmen */
                double incrementor = (wall_start_x - wall_end_x) / (wall_start_y - wall_end_y);

                /* y-Achse entlanglaufen */
                for (double y = (wall_start_y < wall_end_y ? wall_start_y : wall_end_y); y < (wall_start_y < wall_end_y ? wall_end_y : wall_start_y); y++) {
                    /* x-Koordinate bestimmen */
                    double x = (wall_start_y < wall_end_y ? wall_start_x : wall_end_x) + (incrementor * (y - (wall_start_y < wall_end_y ? wall_start_y : wall_end_y)));

                    /* Zustand des Feldes setzen */
                    set_field_state ((int)(x / FIELD_SIZE), (int)(y / FIELD_SIZE), FieldState.WALL, Map.FieldState.UNKNOWN);
                }
            }
        }

        /* Markiert die Felder, auf denen sich der Roboter gerade befindet, als frei */
        public void mark_visited_fields (int position_x, int position_y) {
            /* Robotergröße in Felder umrechnen */
            int robot_fields = ROBOT_SIZE / FIELD_SIZE;

            /* Roboterposition in Felder umrechnen */
            int position_fields_x = position_x / FIELD_SIZE;
            int position_fields_y = position_y / FIELD_SIZE;

            /* Durch den Roboter bedeckte Felder durchlaufen */
            for (int x = 0; x < robot_fields; x++) {
                for (int y = 0; y < robot_fields; y++) {
                    /* Feld bestimmen */
                    int field_x = position_fields_x - (robot_fields / 2) + x;
                    int field_y = position_fields_y - (robot_fields / 2) + y;

                    /* Falls das Feld nicht gesetzt war, dieses auf "Frei" setzen */
                    set_field_state (field_x, field_y, FieldState.FREE, FieldState.UNKNOWN);
                }
            }
        }

        public double? get_first_free_way (int position_x, int position_y, bool allow_revisiting = false) {
            /* Gibt an, ob ein möglicher Weg begonnen hat */
            bool way_started = false;

            /* Informationen über den Startpunkt eines Weges */
            int way_start_x = 0;
            int way_start_y = 0;
            double way_start_direction = 0;

            /* Mehrere Scans mit steigendem Abstand zum Roboter durchführen */
            for (int i = 2; i < 6; i++) {
                /* Zuletzt geprüfter Winkel */
                double direction = 0;

                /* Koordinaten des zuletzt geprüften Feldes */
                int field_x = 0;
                int field_y = 0;

                /* Umgebung des Roboters vollständig abscannen */
                for (int j = -180; j < 180; j++) {
                    /* Winkel in Bogenmaß umrechnen */
                    direction = (Math.PI / 180) * j;

                    /* Koordinaten des zu prüfenden Feldes bestimmen */
                    field_x = (int)((position_x / FIELD_SIZE) + (Math.cos (direction) * i));
                    field_y = (int)((position_y / FIELD_SIZE) + (Math.sin (direction) * i));

                    /* Zustand des Feldes bestimmen */
                    FieldState field_state = get_field_state (field_x, field_y);
                    bool is_free = field_state == FieldState.UNKNOWN || (allow_revisiting && field_state == FieldState.FREE);

                    /* Hat bereits ein Weg begonnen? */
                    if (way_started) {
                        /* Ist der Weg am entsprechenden Winkel weiterhin frei? */
                        if (!is_free) {
                            /* Der Weg ist zuende, Wegesbreite (bzw. Länge des Einganges) bestimmen */
                            int way_length = (int)(Math.sqrt (Math.pow (field_x - way_start_x, 2) + Math.pow (field_y - way_start_y, 2)));

                            /* Prüfen, ob der Weg für den Roboter breit genug ist */
                            if (way_length >= ROBOT_SIZE / FIELD_SIZE) {
                                /* Durchschnittlichen Winkel für Wegesrichtung zurückgeben */
                                return ((way_start_direction + direction) / 2 - (Math.PI / 2));
                            } else {
                                /* Weg verwerfen und weitersuchen */
                                way_started = false;
                            }
                        }
                    } else {
                        /* Könnte hier ein Weg beginnen? */
                        if (is_free) {
                            /* Informationen über den Startpunkt setzen */
                            way_start_x = field_x;
                            way_start_y = field_y;
                            way_start_direction = direction;

                            /* Ein Weg hat begonnen, nach dem Ende suchen */
                            way_started = true;
                        }
                    }
                }

                /* Wurde ein Weg noch nicht beendet? (Könnte z.B. auftreten, wenn der Roboter im Freien steht) */
                if (way_started) {
                    /* Der Weg ist zuende, Wegesbreite (bzw. Länge des Einganges) bestimmen */
                    int way_length = (int)(Math.sqrt (Math.pow (field_x - way_start_x, 2) + Math.pow (field_y - way_start_y, 2)));

                    /* Prüfen, ob der Weg für den Roboter breit genug ist */
                    if (way_length >= ROBOT_SIZE / FIELD_SIZE) {
                        /* Durchschnittlichen Winkel für Wegesrichtung zurückgeben */
                        return ((way_start_direction + direction) / 2 - (Math.PI / 2));
                    } else {
                        /* Weg verwerfen und weitersuchen */
                        way_started = false;
                    }
                }
            }

            /* Ist dies der erste Versuch? */
            if (!allow_revisiting) {
                /* Einschränkungen entschärfen und auch besuchte Felder einbeziehen */
                return get_first_free_way (position_x, position_y, true);
            }

            /* Keinen Weg gefunden, festgefahren */
            return null;
        }
    }

    /* Der maximale erlaubte Abstand zwischen den Auftrittspunkten der Messwerte, damit eine Wand erkannt wird */
    private static const int WALL_MAX_DISTANCE_GAP = 60;

    /* Die maximale erlaubte Richtungsdifferenz zwischen den Auftrittspunkten der Messwerte, damit eine Wand erkannt wird */
    private static const double WALL_MAX_DIRECTION_GAP = (Math.PI / 180) * 40;

    /* Der maximale Radius, in dem der Roboter Messdaten als zuverlässig einstuft */
    private static const int MAX_DETECTION_RADIUS = 150;

    /* Der maximale Abstand zwischen zwei nahe beieienander liegenden Merkmalen */
    private static const int MARK_MAX_DISTANCE_GAP = 30;

    /* Die maximale erlaubte Abweichung der errechneten Fahrtrichtung zur erwarteten */
    private static const double MAX_STEP_DIRECTION_INACCURACY = (Math.PI / 180) * 5;

    /* Die maximale erlaubte Abweichung der errechneten Schrittrichtung zur erwarteten */
    private static const int MAX_STEP_LENGTH_INACCURACY = 10;

    /* Der maximale erlaubte Winkelunterschied zur Wegesrichtung bis eine Drehung durchgeführt wird */
    private static const double MAX_TURNING_DIRECTION_DIFFERENCE = (Math.PI / 180) * 10;

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
                                /* Neue Struktur, die die Wand beschreibt, anlegen */
                                Wall wall = { wall_start_angle,
                                              wall_start_position_x,
                                              wall_start_position_y,
                                              last_angle,
                                              last_position_x,
                                              last_position_y,
                                              last_distance };

                                /* Weitere Angaben errechnen */
                                wall.enhance_data ();

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
                        /* Neue Struktur, die die Wand beschreibt, anlegen */
                        Wall wall = { wall_start_angle,
                                      wall_start_position_x,
                                      wall_start_position_y,
                                      last_angle,
                                      last_position_x,
                                      last_position_y,
                                      last_distance };

                        /* Weitere Angaben errechnen */
                        wall.enhance_data ();

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
            /* Neue Struktur, die die Wand beschreibt, anlegen */
            Wall wall = { wall_start_angle,
                          wall_start_position_x,
                          wall_start_position_y,
                          last_angle,
                          last_position_x,
                          last_position_y,
                          last_distance };

            /* Weitere Angaben errechnen */
            wall.enhance_data ();

            /* Wand zur Liste hinzufügen */
            walls += wall;
        }

        /* Liste der Wände zurückgeben */
        return walls;
    }

    /* Filtert die Liste der Wände nach deren Entfernung zum Roboter. */
    private static Wall[] filter_walls (Wall[] walls) {
        /* Liste der gefilterten Wände */
        Wall[] filtered_walls = {};

        /* Alle Wände durchlaufen */
        for (int i = 0; i < walls.length; i++) {
            /* Wandinformationen abrufen */
            Wall wall = walls[i];

            /* Mittelpunkt der Wand ermitteln */
            int center_x = (wall.relative_start_x + wall.relative_end_x).abs () / 2;
            int center_y = (wall.relative_start_y + wall.relative_end_y).abs () / 2;

            /* Abstand des Mittelpunktes zum Roboter bestimmen */
            int distance_gap = (int)(Math.sqrt (Math.pow (center_x, 2) + Math.pow (center_y, 2)));

            /* Wände mit zu großem Abstand ignorieren */
            if (distance_gap > MAX_DETECTION_RADIUS) {
                continue;
            }

            /* Wand übernehmen */
            filtered_walls += wall;
        }

        /* Gefilterte Liste zurückgeben */
        return filtered_walls;
    }

    /* Stellt aus den Wanddaten Merkmale heraus und gibt diese zurück */
    private static Mark[] detect_marks (Wall[] walls) {
        /* Liste der erkannten Merkmale */
        Mark[] marks = {};

        /* Merkt sich die vorherige Wand */
        Wall? last_wall = null;

        /* Alle Wände durchlaufen */
        for (int i = 0; i < walls.length; i++) {
            /* Wandinformationen abrufen */
            Wall wall = walls[i];

            /* Mit der zweiten Wand beginnen */
            if (last_wall != null) {
                /* Differenz der Wandrichtungen berechnen */
                double direction_difference = Math.fabs (last_wall.relative_direction - wall.relative_direction);

                /* Differenz prüfen */
                if (direction_difference > Math.PI / 2.5 && direction_difference < Math.PI / 3 * 2) {
                    /*
                     * Schnittpunktberechnung orientiert an https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection
                     * Für bessere Lesbarkeit Werte zwischenspeichern
                     */
                    double x1 = last_wall.relative_start_x;
                    double x2 = last_wall.relative_end_x;
                    double x3 = wall.relative_start_x;
                    double x4 = wall.relative_end_x;
                    double y1 = last_wall.relative_start_y;
                    double y2 = last_wall.relative_end_y;
                    double y3 = wall.relative_start_y;
                    double y4 = wall.relative_end_y;

                    /* Zaehler */
                    double zx = (x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4);
                    double zy = (x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4);

                    /* Nenner */
                    double n = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);

                    /* Prüfen, ob die Wände einen Schittpunkt haben */
                    if (n != 0) {
                        /* Koordinaten des Schnittpunktes abrufen */
                        double mark_position_x = zx / n;
                        double mark_position_y = zy / n;

                        /* Durchschnittliche Richtung bestimmen */
                        double avg_direction = (last_wall.relative_direction + wall.relative_direction) / 2;

                        /* Merkmal erstellen */
                        Mark mark = {
                            (int)mark_position_x,
                            (int)mark_position_y,
                            avg_direction,
                            MarkType.CORNER
                        };

                        /* Merkmal zur Liste hinzufügen */
                        marks += mark;
                    }
                }
            }

            /* Wand als vorherige Wand merken */
            last_wall = wall;
        }

        /* Merkmale zurückgeben */
        return marks;
    }

    /* Rotiert die vorherigen Merkmale um ein Hauptmerkmal, sodass eine Deckungsgleichheit zum Zielmerkmal entsteht */
    private static Mark[] rotate_marks (Mark[] old_marks, Mark old_main_mark, Mark target_mark) {
        /* Die transformierten Merkmale */
        Mark[] rotated_marks = {};

        /* Die Verschiebung des Merkmals */
        int mark_movement_x = target_mark.position_x - old_main_mark.position_x;
        int mark_movement_y = target_mark.position_y - old_main_mark.position_y;

        /* Richtungsdifferenz; Alle anderen Merkmale müssen mit diesem Winkel um das Hauptmerkmal herum gedreht werden */
        double rotating_angle = target_mark.direction - old_main_mark.direction;

        /* Alte Merkmale durchlaufen und nacheinander transformieren */
        for (int i = 0; i < old_marks.length; i++) {
            /* Merkmal abrufen */
            Mark mark = old_marks[i];

            /* Neue Position bestimmen */
            int new_position_x = mark.position_x + mark_movement_x;
            int new_position_y = mark.position_y + mark_movement_y;

            /* Abstand der Marke zum Dreh-Mittelpunkt bestimmen */
            int distance_to_target_mark = (int)(Math.sqrt (Math.pow (new_position_x - target_mark.position_x, 2) + Math.pow (new_position_y - target_mark.position_y, 2)));

            /* Neuen Winkel berechnen */
            double new_direction = Math.atan ((double)(new_position_y - target_mark.position_y) / (double)(new_position_x - target_mark.position_x)) + rotating_angle;

            /* Punkt nach Verschiebung durch den Winkel nach gegebenem Abstand neu positionieren */
            new_position_x -= (int)(Math.sin (new_direction) * distance_to_target_mark);
            new_position_y += (int)(Math.cos (new_direction) * distance_to_target_mark);

            /* Verschobenes Merkmal erstellen */
            Mark rotatetd_mark = {
                new_position_x,
                new_position_y,
                new_direction,
                MarkType.CORNER
            };

            /* Merkmal zur Liste hinzufügen */
            rotated_marks += rotatetd_mark;
        }

        /* Transformierte Merkmale zurückgeben */
        return rotated_marks;
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

        /* Berechnet die fehlenden Angaben anhand der gegebenen Werte */
        public void enhance_data () {
            /*
             * Länge der Wand berechnen
             * Viele Grüße von Herrn Pythagoras :-)
             */
            wall_length = (int)(Math.sqrt (Math.pow (relative_end_x - relative_start_x, 2) + Math.pow (relative_end_y - relative_start_y, 2)));

            /* Teilen durch Null verhindern */
            if (relative_end_x == relative_start_x) {
                return;
            }

            /* Relative Richtung der Wand in Bezug zum Roboter berechnen */
            relative_direction = Math.atan ((double)(relative_end_y - relative_start_y) / (double)(relative_end_x - relative_start_x));
        }
    }

    /* Stellt ein Wiedererkennungsmerkmal dar */
    public struct Mark {
        /* Relative Koordinaten des Merkmales */
        int position_x;
        int position_y;

        /* Die Richtung */
        double direction;

        /* Die Art des Merkmals */
        MarkType type;

        /* Gibt an, ob das übergebende Merkmal in der Nähe liegt */
        public bool is_near (Mark mark, int max_distance_gab = MARK_MAX_DISTANCE_GAP) {
            /* Abstand zwischen den Merkmalen berechnen */
            int distance_gap = (int)(Math.sqrt (Math.pow (position_x - mark.position_x, 2) + Math.pow (position_y - mark.position_y, 2)));

            /* Zurückgeben, ob die Merkmale nahe beieinander liegen */
            return (distance_gap <= max_distance_gab);
        }
    }

    /* Die verschiedenen Arten von Merkmalen */
    public enum MarkType {
        /* Dies dient der Erweiterbarkeit, vorerst werden nur Ecken behandelt. */
        CORNER
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

    /* Die Umgebungskarte die erstellt wird */
    private Map map;

    /* Zuletzt erkannte Wandliste */
    public Wall[]? last_detected_walls { get; private set; default = null; }

    /* Zuletzt erkannte Merkmalsliste */
    public Mark[]? last_detected_marks { get; private set; default = null; }

    /* Das zuletzt zur Orientierung genutzte Merkmal */
    public Mark[]? compared_orientation_marks { get; private set; default = null; }

    /* Die selbstbezüglich ermittelte Roboterposition und Richtung, ausgehend von der Startposition. */
    public int robot_position_x { get; private set; default = 0; }
    public int robot_position_y { get; private set; default = 0; }
    public double robot_direction { get; private set; default = 0; }

    /* Speichert die Distanzwerte des momentanen Scanvorganges */
    private Gee.TreeMap<double? , uint16> current_scan;

    /* Geschätze Roboterrichtung nach der Drehung */
    private double expected_step_direction = 0;

    /* Geschätzte Länge der Roboterfortbewegung */
    private int expected_step_length = 0;

    /* Wird ausgelöst, wenn die Umgebungskarte aktualisiert wurde */
    public signal void map_changed (Map map);

    /* Der Konstruktor der Klasse, hier sollten die nötigen Funktionen zur Kontrolle des Roboters übergeben werden */
    public MappingAlgorithm (MoveFunc move_func, TurnFunc turn_func, StartNewScanFunc start_new_scan_func) {
        /* Funktionen global zuweisen */
        this.move = move_func;
        this.turn = turn_func;
        this.start_new_scan = start_new_scan_func;

        /* Karte erstellen */
        map = new Map ();

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
        /* Wände anhand der Messdaten detektieren und direkt filtern */
        Wall[] walls = filter_walls (detect_walls (current_scan));

        /* Wände speichern, damit sie extern abgerufen werden können */
        last_detected_walls = walls;

        /* Die Wände auf Merkmale untersuchen */
        Mark[] marks = detect_marks (walls);

        /* Nach vergleichbaren Merkmalen suchen */
        Mark[] comparable_marks = search_comparable_marks (marks);

        /* Die Informationen über den zurückgelegten Schritt */
        double step_direction = 0;
        int step_length = 0;

        /* Wurden vergleichbare Merkmale gefunden? */
        if (comparable_marks.length == 2 && !comparable_marks[0].is_near (comparable_marks[1], 5)) {
            /* Roboterdrehung neu ermitteln */
            step_direction = robot_direction + (comparable_marks[1].direction - comparable_marks[0].direction);

            /* Abstand zwischen den beiden Merkmalen bestimmen */
            step_length = (int)(Math.sqrt (Math.pow (comparable_marks[1].position_x - comparable_marks[0].position_x, 2) + Math.pow (comparable_marks[1].position_y - comparable_marks[0].position_y, 2)));

            /* Durchschnittlichen Abstand der beiden Merkmale zum Roboter bestimmen */
            int avg_mark_distance_to_robot = (int)((Math.sqrt (Math.pow (comparable_marks[0].position_x, 2) + Math.pow (comparable_marks[0].position_y, 2)) +
                                                    Math.sqrt (Math.pow (comparable_marks[1].position_x, 2) + Math.pow (comparable_marks[1].position_y, 2))) / 2);

            /* Durch die Drehung hervorgerufenen Abstand von der Schrittlänge abziehen */
            step_length -= (int)(Math.sin ((comparable_marks[1].direction - comparable_marks[0].direction) / 2) * avg_mark_distance_to_robot * 2);

            /* Orientierungsmarken speichern */
            compared_orientation_marks = comparable_marks;
        } else {
            /* Keine Orientierungsmarken vorhanden */
            compared_orientation_marks = null;
        }

        /* Wurden genauere Schrittinformationen erfasst? */
        if (compared_orientation_marks == null) {
            /* Érwartete Informationen übernehmen */
            step_direction = expected_step_direction;
            step_length = expected_step_length;
        } else {
            /* Abweichung der Informationen überprüfen */
            if (Math.fabs (step_direction - expected_step_direction) > MAX_STEP_DIRECTION_INACCURACY || (step_length - expected_step_length).abs () > MAX_STEP_LENGTH_INACCURACY) {
                /* Erwartete Werte stattdessen übernehmen */
                step_direction = expected_step_direction;
                step_length = expected_step_length;
            }
        }

        /* Roboterposition um einen Schritt ergänzen */
        robot_position_x -= (int)(Math.sin (step_direction) * step_length);
        robot_position_y += (int)(Math.cos (step_direction) * step_length);

        /* Roboterrichtung übernehmen */
        robot_direction = step_direction;

        /* Merkmale speichern, damit sie extern abgerufen werden können */
        last_detected_marks = marks;

        /* Wände durchlaufen */
        foreach (Wall wall in walls) {
            /* Wand in die Karte einzeichnen */
            map.set_wall_fields (robot_position_x, robot_position_y, robot_direction, wall);
        }

        /* Nächte Bewegungsrichtung mit Backtracking bestimmen */
        double? next_direction = map.get_first_free_way (robot_position_x, robot_position_y);

        /* Aktuelle Roboterposition als "Frei" kennzeichnen */
        map.mark_visited_fields (robot_position_x, robot_position_y);

        /* Die Karte wurde aktualisiert */
        map_changed (map);

        /* Differenz der aktuellen Drehung zur Wegesrichtung bestimmen */
        double direction_difference = (next_direction == null ? 0 : next_direction - robot_direction);

        /* Die Zeit, die für den Bewegungsvorgang benötigt wird */
        uint movement_time = 0;

        /* Muss die Roboterdrehung korrigiert werden? */
        if (Math.fabs (direction_difference) > MAX_TURNING_DIRECTION_DIFFERENCE) {
            /* Länge der Drehung berechnen */
            movement_time = (uint)(Math.fabs (direction_difference) * 500);

            /* Roboterdrehung korrigieren */
            turn (100 * (direction_difference >= 0 ? 1 : -1), movement_time);

            expected_step_direction = robot_direction + (0.001 * movement_time * (direction_difference >= 0 ? 1 : -1));
            expected_step_length = 0;
        } else {
            /* Länge der Fortbewegung berechnen */
            movement_time = 500;

            /* Forwärts fahren */
            move (100, movement_time);

            expected_step_direction = robot_direction;
            expected_step_length = 8;
        }

        /* Neue Messreihe beginnen */
        current_scan = new Gee.TreeMap<double? , uint16> ();

        /* Neuen Scanvorgang einleiten */
        Timeout.add (movement_time + 200, () => {
            start_new_scan ();

            return false;
        });
    }

    /* Sucht ein vorheriges und ein aktuelles Merkmal, das einen Positionsvergleich zulässt */
    private Mark[] search_comparable_marks (Mark[] marks) {
        /* Der Rekord an übereinstimmenden Merkmalen */
        int best_accepted_marks = 0;

        /* Das am besten passende Merkmalspaar */
        Mark[] comparable_marks = {};

        /* Alle aktuellen Merkmale durchlaufen */
        for (int i = 0; i < marks.length; i++) {
            /* Alle vorherigen Merkmale nacheinander durchprobieren und einpassen */
            for (int j = 0; j < last_detected_marks.length; j++) {
                /* Vorherige Merkmale transformieren, sodass sie auf die aktuellen Merkmale passen sollten */
                Mark[] rotated_marks = rotate_marks (last_detected_marks, last_detected_marks[j], marks[i]);

                /* Deckungsgleiche Merkmale zählen */
                int accepted_marks = 0;

                /* Transformierte Merkmale durchprüfen */
                for (int k = 0; k < rotated_marks.length; k++) {
                    /* Originalmerkmal mit gleicher Position suchen */
                    for (int l = 0; l < marks.length; l++) {
                        /* Prüfen, ob die Merkmale aufeinander liegen */
                        if (rotated_marks[k].is_near (marks[l])) {
                            /* Ein weiteres deckungsgleiches Merkmal zählen */
                            accepted_marks++;
                        }
                    }
                }

                /* Überschreitet die Trefferquote den bisherigen Rekord? */
                if (accepted_marks > best_accepted_marks) {
                    /* Neue Trefferquote und zugehöriges Merkmalspaar speichern */
                    best_accepted_marks = accepted_marks;
                    comparable_marks = { marks[i], last_detected_marks[j] };
                }
            }
        }

        /* Merkmalspaar zurückgeben */
        return comparable_marks;
    }
}