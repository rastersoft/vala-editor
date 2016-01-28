namespace Editor {
	public class DocumentManager : Gtk.Notebook {
		construct {
			engine = new Engine();
		}
		
		public bool contains (string path) {
			bool result = false;
			this.foreach (widget => {
				if (widget is Document && (widget as Document).location == path)
					result = true;
			});
			return result;
		}

		public Document? find_document (string path) {
			Document? result = null;
			this.foreach (widget => {
				if (widget is Document && (widget as Document).location == path)
					result = widget as Document;
			});
			return result;
		}

		public void add_document (string path) {
			var document = new Document (path);
			document.manager = this;
			engine.add_document (document);
			var sw = new Gtk.ScrolledWindow (null, null);
			sw.add (document);
			document.notebook_page = append_page (sw, null);
		}
		
		public Engine engine { get; private set; }
	}
}
