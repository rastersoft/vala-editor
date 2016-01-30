namespace Editor {
	public class DocumentManager : Gtk.Notebook {

		construct {
			engine = new Engine();
		}

		public bool contains (string path) {
			return (this.find_document_internal(this,path) == null) ? false : true;
		}

		public Document? find_document (string path) {
			return this.find_document_internal(this,path);
		}

		/* Since each document widget is inside a Gtk.ScrolledWindow, it is a must to do a recursive search */
		private Document ? find_document_internal(Gtk.Widget widget, string path) {
			Editor.Document? result = null;

			if (widget is Editor.Document) {
				if ((widget as Editor.Document).location == path) {
					result = (widget as Editor.Document);
				}
			} else if (widget is Gtk.Container) {
				foreach (var widget2 in (widget as Gtk.Container).get_children()) {
					var result2 = this.find_document_internal(widget2,path);
					if (result2 != null) {
						result = result2;
						break;
					}
				}
			}

			return result;
		}

		public Document add_document (string path) {
			var document = new Document (path);
			document.manager = this;
			engine.add_document (document);
			var sw = new Gtk.ScrolledWindow (null, null);
			sw.add (document);
			append_page (sw, new Gtk.Label(GLib.Path.get_basename(path)));
			document.top_container = sw; // this allows to easily find in which page is a document, given its associated file
			return document;
		}
		
		public Engine engine { get; private set; }
	}
}
