namespace Editor {
	public class Engine : GLib.Object, Gtk.SourceCompletionProvider {
		Vala.CodeContext context;
		Vala.Parser parser;
		BlockLocator locator;
		
		construct {
			locator = new BlockLocator();
			context = new Vala.CodeContext();
			context.profile = Vala.Profile.GOBJECT;
			parser = new Vala.Parser();
			parser.parse (context);
		}
		
		public void add_document (Document document) {
			Vala.CodeContext.push (context);
			foreach (var file in context.get_source_files()) {
				if (file.filename == document.location) {
					Vala.CodeContext.pop();
					return;
				}
			}
			document.saved.connect (() => {
				foreach (var file in context.get_source_files())
					if (file.filename == document.location) {
						file.content = document.buffer.text;
						update_file (file);
					}
			});
			context.add_source_filename (document.location);
			if (!context.has_package ("gobject-2.0")) {
				context.add_external_package ("glib-2.0");
				context.add_external_package ("gobject-2.0");
			}
			Vala.CodeContext.pop();
			parse();
		}
		
		void update_file (Vala.SourceFile file) {
			lock (context) {
				var nodes = new Vala.ArrayList<Vala.CodeNode>();
				foreach (var node in file.get_nodes())
					nodes.add (node);
				foreach (var node in nodes) {
					file.remove_node (node);
					if (node is Vala.Symbol) {
						var sym = (Vala.Symbol)node;
						if (sym.owner != null)
							sym.owner.remove (sym.name);
						if (context.entry_point == sym)
							context.entry_point = null;
					}
				}
				file.current_using_directives = new Vala.ArrayList<Vala.UsingDirective>();
				var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib"));
				file.add_using_directive (ns_ref);
				context.root.add_using_directive (ns_ref);
				parse ();
			}
		}
		
		public Vala.Symbol? lookup_symbol_at (string filename, int line, int column) {
			Vala.SourceFile? source = null;
			lock (context) {
				foreach (var file in context.get_source_files()) {
					if (file.filename == filename) 
						source = file;
				}
			}
			if (source == null)
				return null;
			return locator.locate (source, line, column);
		}
		
		void append_visible_symbols (Vala.List<Vala.Symbol> list, Vala.Symbol? symbol, Vala.SymbolAccessibility access) {
			if (symbol == null)
				return;
			if (symbol is Vala.Method) {
				var method = symbol as Vala.Method;
				foreach (var lv in method.body.get_local_variables())
					list.add (lv);
				foreach (var prm in method.get_parameters())
					list.add (prm);
			}
			else if (symbol is Vala.Class) {
				var klass = symbol as Vala.Class;
				foreach (var cls in klass.get_classes())
					list.add (cls);
				foreach (var c in klass.get_constants())
					list.add (c);
				foreach (var d in klass.get_delegates())
					list.add (d);
				foreach (var e in klass.get_enums())
					list.add (e);
				foreach (var f in klass.get_fields())
					list.add (f);
				foreach (var m in klass.get_methods())
					list.add (m);
				foreach (var p in klass.get_properties())
					list.add (p);
				foreach (var s in klass.get_signals())
					list.add (s);
				foreach (var s in klass.get_structs())
					list.add (s);
			}
			else if (symbol is Vala.Struct) {
				var st = symbol as Vala.Struct;
				foreach (var c in st.get_constants())
					list.add (c);
				foreach (var f in st.get_fields())
					list.add (f);
				foreach (var m in st.get_methods())
					list.add (m);
				foreach (var p in st.get_properties())
					list.add (p);
			}
			else if (symbol is Vala.Namespace) {
				var ns = symbol as Vala.Namespace;
				foreach (var cls in ns.get_classes())
					list.add (cls);
				foreach (var c in ns.get_constants())
					list.add (c);
				foreach (var d in ns.get_delegates())
					list.add (d);
				foreach (var e in ns.get_enums())
					list.add (e);
				foreach (var ed in ns.get_error_domains())
					list.add (ed);
				foreach (var f in ns.get_fields())
					list.add (f);
				foreach (var i in ns.get_interfaces())
					list.add (i);
				foreach (var m in ns.get_methods())
					list.add (m);
				foreach (var n in ns.get_namespaces())
					list.add (n);
				foreach (var s in ns.get_structs())
					list.add (s);
			}
			
			if (symbol.parent_symbol != null)
				append_visible_symbols (list, symbol.parent_symbol, access);
		}
		
		public Vala.List<Vala.Symbol> lookup_visible_symbols_at (string filename, int line, int column) {
			var symbol = lookup_symbol_at (filename, line, column);
			if (symbol == null)
				symbol = lookup_symbol_at (filename, line - 1, column);
			var list = new Vala.ArrayList<Vala.Symbol>();
			var any = Vala.SymbolAccessibility.PRIVATE | Vala.SymbolAccessibility.PUBLIC | Vala.SymbolAccessibility.INTERNAL | Vala.SymbolAccessibility.PROTECTED;
			append_visible_symbols (list, symbol, any);
			lock (context) {
				foreach (var file in context.get_source_files()) {
					if (file.file_type == Vala.SourceFileType.SOURCE && file.filename != filename) {
						foreach (var ud in file.current_using_directives)
							append_visible_symbols (list, ud.namespace_symbol, any);
						foreach (var node in file.get_nodes()) 
							if (node is Vala.Symbol) {
								var sym = node as Vala.Symbol;
								if (symbol != null && sym.is_accessible (symbol) && sym.parent_symbol.name == null)
									list.add (sym);
							}
					}
				}
			}
			return list;
		}
		
		public Vala.List<Vala.Symbol> get_symbols_for_name (Vala.Symbol symbol, string name, bool match, Vala.MemberBinding binding = Vala.MemberBinding.CLASS) {
			if (symbol is Vala.Method)
				return get_symbols_for_name ((symbol as Vala.Method).return_type.data_type, name, match, (symbol as Vala.Method).binding);
			if (symbol is Vala.Parameter)
				return get_symbols_for_name ((symbol as Vala.Parameter).variable_type.data_type, name, match, Vala.MemberBinding.INSTANCE);
			if (symbol is Vala.Field)
				return get_symbols_for_name ((symbol as Vala.Field).variable_type.data_type, name, match, (symbol as Vala.Field).binding);
			if (symbol is Vala.LocalVariable)
				return get_symbols_for_name ((symbol as Vala.LocalVariable).variable_type.data_type, name, match, Vala.MemberBinding.INSTANCE);
			if (symbol is Vala.Namespace)
				return get_symbols_for_namespace (symbol as Vala.Namespace, name, match, binding);
			if (symbol is Vala.Class)
				return get_symbols_for_class (symbol as Vala.Class, name, match, binding);
			if (symbol is Vala.Struct)
				return get_symbols_for_struct (symbol as Vala.Struct, name, match, binding);
			if (symbol is Vala.Enum)
				return get_symbols_for_enum (symbol as Vala.Enum, name, match, binding);
			if (symbol is Vala.ErrorDomain)
				return get_symbols_for_error_domain (symbol as Vala.ErrorDomain, name, match, binding);
			return new Vala.ArrayList<Vala.Symbol>();
		}
		
		Vala.List<Vala.Symbol> get_symbols_for_error_domain (Vala.ErrorDomain ed, string name, bool match, Vala.MemberBinding binding) {
			var list = new Vala.ArrayList<Vala.Symbol>();
			if (binding == Vala.MemberBinding.CLASS) {
				foreach (var code in ed.get_codes())
					if ((match && name == code.name) || code.name.has_prefix (name))
						list.add (code);
			} 
			foreach (var m in ed.get_methods()) {
				if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && m.binding == Vala.MemberBinding.STATIC)
					if ((match && name == m.name) || m.name.has_prefix (name))
						list.add (m);
			}
			return list;
		}
		
		Vala.List<Vala.Symbol> get_symbols_for_enum (Vala.Enum e, string name, bool match, Vala.MemberBinding binding) {
			var list = new Vala.ArrayList<Vala.Symbol>();
			if (binding == Vala.MemberBinding.CLASS) {
				foreach (var c in e.get_constants())
					if ((match && name == c.name) || c.name.has_prefix (name))
						list.add (c);
				foreach (var ev in e.get_values())
					if ((match && name == ev.name) || ev.name.has_prefix (name))
						list.add (ev);
			}
			foreach (var m in e.get_methods())
				if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && m.binding == Vala.MemberBinding.STATIC)
					if ((match && name == m.name) || m.name.has_prefix (name))
						list.add (m);
			return list;
		}
		
		Vala.List<Vala.Symbol> get_symbols_for_namespace (Vala.Namespace ns, string name, bool match, Vala.MemberBinding binding) {
			var list = new Vala.ArrayList<Vala.Symbol>();
			foreach (var cls in ns.get_classes())
				if ((match && name == cls.name) || cls.name.has_prefix (name))
					list.add (cls);
			foreach (var c in ns.get_constants())
				if ((match && name == c.name) || c.name.has_prefix (name))
					list.add (c);
			foreach (var d in ns.get_delegates())
				if ((match && name == d.name) || d.name.has_prefix (name))
					list.add (d);
			foreach (var e in ns.get_enums())
				if ((match && name == e.name) || e.name.has_prefix (name))
					list.add (e);
			foreach (var ed in ns.get_error_domains())
				if ((match && name == ed.name) || ed.name.has_prefix (name))
					list.add (ed);
			foreach (var f in ns.get_fields())
				if ((match && name == f.name) || f.name.has_prefix (name))
					list.add (f);
			foreach (var i in ns.get_interfaces())
				if ((match && name == i.name) || i.name.has_prefix (name))
					list.add (i);
			foreach (var n in ns.get_namespaces())
				if ((match && name == n.name) || n.name.has_prefix (name))
					list.add (n);
			foreach (var m in ns.get_methods())
				if ((match && name == m.name) || m.name.has_prefix (name))
					list.add (m);
			foreach (var s in ns.get_structs())
				if ((match && name == s.name) || s.name.has_prefix (name))
					list.add (s);
			return list;
		}
		
		Vala.List<Vala.Symbol> get_symbols_for_class (Vala.Class klass, string name, bool match, Vala.MemberBinding binding) {
			var list = new Vala.ArrayList<Vala.Symbol>();
			if (binding == Vala.MemberBinding.CLASS) {
				foreach (var cls in klass.get_classes())
					if ((match && name == cls.name) || cls.name.has_prefix (name))
						list.add (cls);
				foreach (var c in klass.get_constants())
					if ((match && name == c.name) || c.name.has_prefix (name))
						list.add (c);
				foreach (var d in klass.get_delegates())
					if ((match && name == d.name) || d.name.has_prefix (name))
						list.add (d);
				foreach (var e in klass.get_enums())
					if ((match && name == e.name) || e.name.has_prefix (name))
						list.add (e);
				foreach (var s in klass.get_structs())
					if ((match && name == s.name) || s.name.has_prefix (name))
						list.add (s);
			}
			foreach (var f in klass.get_fields())
				if (f.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && f.binding == Vala.MemberBinding.STATIC)
					if ((match && name == f.name) || f.name.has_prefix (name))
						list.add (f);
			foreach (var m in klass.get_methods())
				if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && m.binding == Vala.MemberBinding.STATIC)
					if ((match && name == m.name) || m.name.has_prefix (name))
						list.add (m);
			foreach (var p in klass.get_properties())
				if (p.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && p.binding == Vala.MemberBinding.STATIC)
					if ((match && name == p.name) || p.name.has_prefix (name))
						list.add (p);
			foreach (var s in klass.get_signals())
				if (binding != Vala.MemberBinding.CLASS)
					if ((match && name == s.name) || s.name.has_prefix (name))
						list.add (s);
			return list;
		}
		
		Vala.List<Vala.Symbol> get_symbols_for_struct (Vala.Struct st, string name, bool match, Vala.MemberBinding binding) {
			var list = new Vala.ArrayList<Vala.Symbol>();
			if (binding == Vala.MemberBinding.CLASS)
				foreach (var c in st.get_constants())
					if ((match && name == c.name) || c.name.has_prefix (name))
						list.add (c);
			foreach (var f in st.get_fields()) {
				if (f.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && f.binding == Vala.MemberBinding.STATIC)
					if ((match && name == f.name) || f.name.has_prefix (name))
						list.add (f);
			}
			foreach (var m in st.get_methods()) {
				if (m.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && m.binding == Vala.MemberBinding.STATIC)
					if ((match && name == m.name) || m.name.has_prefix (name))
						list.add (m);
			}
			foreach (var p in st.get_properties()) {
				if (p.binding == Vala.MemberBinding.INSTANCE && binding != Vala.MemberBinding.CLASS ||
				binding == Vala.MemberBinding.CLASS && p.binding == Vala.MemberBinding.STATIC)
					if ((match && name == p.name) || p.name.has_prefix (name))
						list.add (p);
			}
			return list;
		}
		
		public signal void end_parsing();
		
		void parse() {
			try {
				Thread.create<void>(() => {
					lock (context) {
						Vala.CodeContext.push (context);
						foreach (var file in context.get_source_files())
							if (file.get_nodes().size == 0)
								parser.visit_source_file (file);
						context.check();
						Vala.CodeContext.pop();
						end_parsing();
					}
				}, false);
			} catch {
			
			}
		}
	}
}
