public abstract class THOMAS.SerialDevice : Object {
	private int handle;

	public SerialDevice (string tty_name, Posix.speed_t baudrate) {
		// Handle erstellen
		handle = Posix.open (tty_name, Posix.O_RDWR | Posix.O_NOCTTY | Posix.LOG_NDELAY);

		if (handle == -1) {
			error ("Öffnen von %s fehlgeschlagen.", tty_name);
		}

		// Device öffnen
		FileStream? tty = FileStream.fdopen (handle, "rw");

		if (tty == null) {
			error ("Laden von %s fehlgeschlagen.", tty_name);
		}

		Posix.termios termios;

		// Attribute abrufen
		if (Posix.tcgetattr (handle, out termios) != 0) {
			error ("Speichern der TTY-Attribute fehlgeschlagen.");
		}

		// TODO: Überprüfen ob wirklich notwendig.
		Posix.termios new_termios = termios;

		// Baudrate setzen
		new_termios.c_ispeed = baudrate;
		new_termios.c_ospeed = baudrate;

		// Programm soll auf Antwort des Arduinos warten
		new_termios.c_cc[Posix.VMIN] = 1;
		new_termios.c_cc[Posix.VTIME] = 1;

		// Schnittstelle konfigurieren
		new_termios.c_cflag |= Posix.CS8;
		new_termios.c_iflag &= ~(Posix.IGNBRK | Posix.BRKINT | Posix.ICRNL | Posix.IXON );
		new_termios.c_oflag &= ~(Posix.OPOST | Posix.ONLCR);
		new_termios.c_lflag &= ~ (Posix.ECHO | Linux.Termios.ECHOCTL | Posix.ICANON | Posix.ISIG | Posix.IEXTEN);

		// Neue Konfiguration übernehmen
		if (Posix.tcsetattr (handle, Posix.TCSAFLUSH, new_termios) != 0) {
			error ("Setzen von TTY-Attributen fehlgeschlagen.");
		}

		debug ("Schnittstelle %s initialisiert.", tty_name);
	}
}