using AutoVala;
using AutovalaPlugin;

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
		private AutovalaPlugin.FileViewer fileViewer;
		private AutovalaPlugin.ProjectViewer projectViewer;
		
		construct {

			var autovala_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			var main_box = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);

			fileViewer = new FileViewer();
			fileViewer.clicked_file.connect(this.file_selected);

			projectViewer = new ProjectViewer();
			projectViewer.clicked_file.connect(this.file_selected);

			var actionButtons = new ActionButtons();
			actionButtons.open_file.connect(this.file_selected);
			this.projectViewer.link_file_view(this.fileViewer);
			this.projectViewer.link_action_buttons(actionButtons);

			var scroll1 = new Gtk.ScrolledWindow(null,null);
			scroll1.add(projectViewer);
			var scroll2 = new Gtk.ScrolledWindow(null,null);
			scroll2.add(fileViewer);

			var container = new AutovalaPlugin.PanedPercentage(Gtk.Orientation.VERTICAL,0.5);

			container.add1(scroll1);
			container.add2(scroll2);

			autovala_box.pack_start(actionButtons,false,true);
			autovala_box.pack_start(new Gtk.Separator (Gtk.Orientation.HORIZONTAL),false,true);
			autovala_box.pack_start(container,true,true);
			main_box.add1(autovala_box);

			manager = new DocumentManager();
			var bar = new Gtk.HeaderBar();
			bar.show_close_button = true;
			bar.title = "Editor";
			
			var button = new Gtk.MenuButton();
			var menu = new Gtk.Menu();
			var fileitem = new Gtk.MenuItem.with_label ("File");
			fileitem.activate.connect (() => {
				var dialog = new FileChooserDialog (this, "Open file(s)");
				string ?last_file = null;
				if (dialog.run() == Gtk.ResponseType.OK) {
					foreach (var file in dialog.get_filenames()) {
						if (!(file in manager)) {
							manager.add_document (file);
						}
						last_file = file;
					}
					this.fileViewer.set_current_file(last_file);
					this.projectViewer.set_current_file(last_file);
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
			main_box.add2(manager);
			add (main_box);
		}

		/**
		 * This callback is called whenever the user clicks on a file, both
		 * in the Project View, or in the File View
		 * @param filepath The file (with full path) clicked by the user
		 */
		public void file_selected(string filepath) {
			if (!(filepath in this.manager)) {
				this.manager.add_document(filepath);
				manager.show_all();
			}
		}

	}
}
