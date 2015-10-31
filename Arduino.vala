public class THOMAS.Arduino : SerialDevice {
	public Arduino (string tty_name) {
		base (tty_name, 115200);
	}
}