public class THOMAS.Main : Object {
	private static const OptionEntry[] OPTIONS = {
		{"arduinotty", 'a', 0, OptionArg.STRING, ref arduino_tty, "Port des Arduinos", "PORT"},
		{null}
	};

	private static string? arduino_tty = null;

	public static void main (string[] args) {
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
	}
}