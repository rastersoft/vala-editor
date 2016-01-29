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
		private AutovalaPlugin.OutputView outputView;
		private AutovalaPlugin.SearchView searchView;
		
		construct {

			var autovala_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			var main_box = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
			var search_box = new AutovalaPlugin.PanedPercentage(Gtk.Orientation.VERTICAL,0.85);
			var search_notebook = new Gtk.Notebook();

			fileViewer = new FileViewer();
			fileViewer.clicked_file.connect(this.file_selected);

			projectViewer = new ProjectViewer();
			projectViewer.clicked_file.connect(this.file_selected);

			this.outputView = new AutovalaPlugin.OutputView();
			
			this.searchView = new AutovalaPlugin.SearchView();
			//this.searchView.open_file.connect(this.file_line_selected);

			var actionButtons = new ActionButtons();
			actionButtons.open_file.connect(this.file_selected);
			this.projectViewer.link_file_view(this.fileViewer);
			this.projectViewer.link_action_buttons(actionButtons);
			this.projectViewer.link_output_view(this.outputView);
			this.projectViewer.link_search_view(this.searchView);

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
				if (dialog.run() == Gtk.ResponseType.OK) {
					Editor.Document? doc = null;
					string? last_file = null;
					foreach (var file in dialog.get_filenames()) {
						last_file = file;
						doc = manager.find_document(file);
						if (doc == null) {
							doc = manager.add_document (file);
						}
					}
					this.fileViewer.set_current_file(last_file);
					this.projectViewer.set_current_file(last_file);
					manager.show_all();
					if ((doc == null) && (last_file != null) {
						doc = manager.find_document(last_file);
					}
					if (doc != null) {
						manager.page = manager.page_num(doc.top_container); // switch to the last of the open document, even if it was already open
					}
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
			main_box.add2(search_box);
			search_box.add1(manager);
			search_box.add2(search_notebook);
			search_notebook.append_page(this.outputView,new Gtk.Label("Autovala output"));
			search_notebook.append_page(this.searchView,new Gtk.Label("Autovala search"));
			add (main_box);
		}

		/**
		 * This callback is called whenever the user clicks on a file, both
		 * in the Project View, or in the File View
		 * @param filepath The file (with full path) clicked by the user
		 */
		public void file_selected(string filepath) {
			var doc = this.manager.find_document(filepath);
			if (doc == null) {
				doc = this.manager.add_document(filepath);
				manager.show_all();
			}
			manager.page = manager.page_num(doc.top_container);
		}

	}
}
