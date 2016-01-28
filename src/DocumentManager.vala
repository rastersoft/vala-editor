using Gee;

namespace Editor {
	public class DocumentManager : Gtk.Notebook {

		Gee.List<Document> documents;

		construct {
			engine = new Engine();
			this.documents = new Gee.ArrayList<Document>();
		}
		
		public bool contains (string path) {
			foreach(var doc in this.documents) {
				if (doc.location == path) {
					return true;
				}
			}
			return false;
		}

		public Document? find_document (string path) {
			foreach(var doc in this.documents) {
				if (doc.location == path) {
					return doc;
				}
			}
			return null;
		}

		public Document add_document (string path) {
			var document = new Document (path);
			document.manager = this;
			engine.add_document (document);
			var sw = new Gtk.ScrolledWindow (null, null);
			sw.add (document);
			document.notebook_page = append_page (sw, null);
			this.documents.add(document);
			return document;
		}
		
		public Engine engine { get; private set; }
	}
}
