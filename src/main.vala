public static void main (string[] args) {
	Gtk.init (ref args);
	var win = new Editor.Window();
	win.set_size_request (400, 300);
	win.show_all();
	Gtk.main();
}
