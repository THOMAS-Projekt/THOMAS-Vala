public class THOMAS.Arduino : SerialDevice {
	public enum MessagePriority {
		INFO,
		WARNING,
		ERROR
	}
	private Mutex mutex = Mutex();

	private bool minimalmode_enabled = false;

	public Arduino (string tty_name) {
		base (tty_name, 9600);
	}

	public void wait_for_initialisation () {
		while (base.read_package ()[0] != 0);
	}

	public void setup (bool minimalmode_enabled) {
		// Heartbeat-Thread
		new Thread<int> (null, () => {
			while (true) {
				mutex.@lock();

				// Heartbeat senden
				base.send_package ({0});

				if(base.read_package()[0] != 1)
					error("Fehler beim Empfangen der Heartbeat Antwort");

				mutex.unlock();
				// Eine Sekunde warten
				Thread.usleep (1000 * 1000);
			}
		});

		if(!minimalmode_enabled) {
			new Thread<int> (null, () => {
				while(true) {
					// TODO: Könnte man implementieren, wenn man Lust hätte!
					get_usensor_distance();
				}
			});
		}

		if(minimalmode_enabled)
			enable_minimalmode();
	}

	// TODO: Rückgabe prüfen
	public void print_message (MessagePriority priority, string message) {
		uint8[] package = {};
		package += 1;
		package += (uint8) priority;
		package += (uint8) message.data.length;

		for (int i = 0; i < message.data.length; i++) {
			package += message.data[i];
		}

		mutex.@lock();

		base.send_package (package);

		mutex.unlock();
	}

	public void enable_minimalmode() {
		mutex.@lock();
		
		base.send_package({5, 1});

		if(base.read_package()[0] != 1) {
			error("Fehler beim aktivieren des Minimalmodus");
		}

		mutex.unlock();

		minimalmode_enabled = true;

		debug("Minimalmodus aktiviert");
	}

	public List<int> get_usensor_distance() {
		if(minimalmode_enabled)
			error("Es können keine USensor Daten im Minimalmodus abgerufen werden");

		List<uint8> distances = new List<uint8> ();

		mutex.@lock();

		base.send_package({2, 0, 0});

		uint8[] data = base.read_package();

		mutex.unlock();

		for(int i = 0; i < data.length; i++)
			distances.append(data[i] * 2);

		return distances;
	}
}