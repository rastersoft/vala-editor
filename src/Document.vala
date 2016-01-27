namespace Editor {
	public class Document : Gtk.SourceView {
		public Document (string path) {
			GLib.Object (location: path);
		}
		
		construct {
			show_line_numbers = true;
			provider = new Provider (this);
			completion.add_provider (provider);
			buffer = new Gtk.SourceBuffer.with_language (new Gtk.SourceLanguageManager().get_language ("vala"));
			buffer.changed.connect (() => {
				text_changed();
			});
			
			key_press_event.connect (event => {
				Gtk.TextIter iter;
				buffer.get_iter_at_mark (out iter, buffer.get_insert());
				line = iter.get_line();
				column = iter.get_line_offset();
				if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0 && event.keyval == Gdk.Key.s) {
					FileUtils.set_contents (location, buffer.text);
					saved();
				}
				return false;
			});
			string text;
			FileUtils.get_contents (location, out text);
			buffer.text = text;
		}
		
		public signal void saved();
		public signal void text_changed();
		
		public int column { get; private set; }
		public int line { get; private set; }
		public string location { get; construct; }
		public Provider provider { get; private set; }
		public DocumentManager manager { get; internal set; }
		
		public Vala.Symbol current_context {
			owned get {
				return manager.engine.lookup_symbol_at (location, line + 1, column);
			}
		}
		
		public Vala.List<Vala.Symbol> visible_symbols {
			owned get {
				return manager.engine.lookup_visible_symbols_at (location, line + 1, column);
			}
		}
	}
}
