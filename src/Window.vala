namespace Editor {
	public class FileChooserDialog : Gtk.FileChooserDialog {
		public FileChooserDialog (Gtk.Window parent, string title) {
			GLib.Object (use_header_bar : 1, action : Gtk.FileChooserAction.OPEN, select_multiple : true,
				transient_for : parent, title : title);
		}
		
		construct {
			var ftr = new Gtk.FileFilter();
			ftr.set_filter_name ("Vala");
			ftr.add_pattern ("*.vala");
			add_filter (ftr);
			add_buttons ("Cancel", Gtk.ResponseType.CANCEL, "OK", Gtk.ResponseType.OK);
		}
	}
	
	public class Window : Gtk.Window {
		DocumentManager manager;
		
		construct {
			manager = new DocumentManager();
			var bar = new Gtk.HeaderBar();
			bar.show_close_button = true;
			bar.title = "Editor";
			
			var button = new Gtk.MenuButton();
			var menu = new Gtk.Menu();
			var fileitem = new Gtk.MenuItem.with_label ("File");
			fileitem.activate.connect (() => {
				var dialog = new FileChooserDialog (this, "Open file(s)");
				if (dialog.run() == Gtk.ResponseType.OK) {
					foreach (var file in dialog.get_filenames())
						if (!(file in manager))
							manager.add_document (file);
					manager.show_all();
				}
				dialog.destroy();
			});
			var quititem = new Gtk.MenuItem.with_label ("Quit");
			menu.add (fileitem);
			menu.add (new Gtk.SeparatorMenuItem());
			menu.add (quititem);
			button.popup = menu;
			menu.show_all();
			
			bar.pack_start (button);
			set_titlebar (bar);
			
			add (manager);
		}
	}
}
