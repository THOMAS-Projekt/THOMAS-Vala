public class THOMAS.Arduino : SerialDevice {
	public Arduino (string tty_name) {
		base (tty_name, 115200);
	}

	public void wait_for_initialisation () {
		while (base.read_package ()[0] != 0);
	}

	public void run () {
		// Heartbeat-Thread
		new Thread<int> (null, () => {
			while (true) {
				// Heartbeat senden
				base.send_package ({0});

				// Eine Sekunde warten
				Thread.usleep (1000 * 1000);
			}
		});
	}
}