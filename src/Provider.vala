namespace Editor {
	public class SymbolItem : GLib.Object, Gtk.SourceCompletionProposal {
		public SymbolItem (Vala.Symbol symbol) {
			GLib.Object (symbol: symbol);
		}
		
		Icon icon;
		
		construct {
			icon = new BytesIcon (resources_lookup_data ("/resources/icons/%s.png".printf (symbol.type_name.substring (4).down()),
				ResourceLookupFlags.NONE));
		}
		
		public unowned GLib.Icon? get_gicon() {
			return icon;
		}
		public unowned string? get_icon_name() { return null; }
		public string? get_info() { return symbol.name; }
		public string get_label() { return symbol.name; }
		public string get_markup() { return symbol.name; }
		public string get_text() { return symbol.name; }
		
		public Vala.Symbol symbol { get; construct; }
	}
	
	public class Provider : GLib.Object, Gtk.SourceCompletionProvider {
		public Provider (Document document) {
			GLib.Object (document: document);
		}
		
		Regex member_access;
		Regex member_access_split;
		
		construct {
			member_access = new Regex ("""((?:\w+(?:\s*\([^()]*\))?\.)*)(\w*)$""");
			member_access_split = new Regex ("""(\s*\([^()]*\))?\.""");
			icon = new Gdk.Pixbuf.from_resource ("/resources/icons/gnome.png");
		}
		
		public Document document { get; construct; }
		
		public string get_name() {
			return "Vala";
		}
		
		Gdk.Pixbuf icon;
		
		public unowned Gdk.Pixbuf? get_icon() {
			return icon;
		}
		
		public void populate (Gtk.SourceCompletionContext context) {
			var list = new List<Gtk.SourceCompletionProposal>();
			Gtk.TextIter iter, start;
			context.get_iter (out iter);
			document.buffer.get_iter_at_line_offset (out start, iter.get_line(), 0);
			string text = start.get_text (iter).strip();
			MatchInfo match_info;
			if (!member_access.match (text, 0, out match_info))
				return;
			if (match_info.fetch(0).length < 1)
				return;
			string prefix = match_info.fetch (2);
			var names = member_access_split.split (match_info.fetch (1));
			if (names.length > 0) {
				text = names[0];
				names[names.length - 1] = prefix;
			}
			foreach (var sym in document.visible_symbols)
				if (sym.name.has_prefix (text))
					list.append (new SymbolItem (sym));
			if (names.length > 0) {
				for (var i = 1; i < names.length; i++) {
					if (list.length() == 0)
						break;
					if (names[i][0] == '(')
						continue;
					var cur = (list.nth_data (0) as SymbolItem).symbol;
					list = new List<Gtk.SourceCompletionProposal>();
					foreach (var sym in document.manager.engine.get_symbols_for_name (cur, names[i], false))
						list.append (new SymbolItem (sym));
				}
			}
			context.add_proposals (this, list, true);
		}
		
		Vala.Expression construct_member_access (string[] names) {
			Vala.Expression expr = null;

			for (var i = 0; names[i] != null; i++) {
				if (names[i] != "") {
					expr = new Vala.MemberAccess (expr, names[i]);
					if (names[i+1] != null && names[i+1].chug ().has_prefix ("(")) {
						expr = new Vala.MethodCall (expr);
						i++;
					}
				}
			}

			return expr;
		}
	}
}
