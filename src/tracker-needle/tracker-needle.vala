//
// Copyright 2010, Martyn Russell <martyn@lanedo.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//

using Gtk;
using Tracker.Sparql;

[CCode (cname = "TRACKER_UI_DIR")]
extern static const string UIDIR;

[CCode (cname = "SRCDIR")]
extern static const string SRCDIR;

public class TrackerNeedle {
	private const string UI_FILE = "tracker-needle.ui";
	private Window window;
	private ToggleToolButton view_list;
	private ToggleToolButton view_icons;
	private ToggleToolButton view_details;
	private ToggleToolButton find_in_contents;
	private ToggleToolButton find_in_titles;
	private Entry search;
	private ToolButton show_stats;
	private ScrolledWindow sw_treeview;
	private TreeView treeview;
	private ScrolledWindow sw_iconview;
	private IconView iconview;
	private uint last_search_id = 0;
	private ListStore store;
	private int size_small = 0;
	private int size_big = 0;
	static bool current_view = true;
	static bool current_find_in = true;

	public void show () {
		setup_ui ();

		window.show ();
	}

	private void setup_ui () {
		var builder = new Gtk.Builder ();

		try {
			//try load from source tree first.
			builder.add_from_file (SRCDIR + UI_FILE);
		} catch (GLib.Error e) {
			//now the install location
			try {
				builder.add_from_file (UIDIR + UI_FILE);
			} catch (GLib.Error e) {
				var msg = new MessageDialog (null,
				                             DialogFlags.MODAL,
				                             MessageType.ERROR,
				                             ButtonsType.CANCEL,
				                             "Failed to load UI file, %s\n",
				                             e.message);
				msg.run ();
				Gtk.main_quit();
			}
		}

		Gtk.icon_size_lookup (Gtk.IconSize.MENU, out size_small, null);
		Gtk.icon_size_lookup (Gtk.IconSize.DIALOG, out size_big, null);

		window = builder.get_object ("window_needle") as Window;
		window.destroy.connect (Gtk.main_quit);

		view_list = builder.get_object ("toolbutton_view_list") as ToggleToolButton;
		view_list.toggled.connect (view_toggled);

		view_icons = builder.get_object ("toolbutton_view_icons") as ToggleToolButton;
		view_icons.toggled.connect (view_toggled);

		view_details = builder.get_object ("toolbutton_view_details") as ToggleToolButton;
		view_details.toggled.connect (view_toggled);

		find_in_contents = builder.get_object ("toolbutton_find_in_contents") as ToggleToolButton;
		find_in_contents.toggled.connect (find_in_toggled);

		find_in_titles = builder.get_object ("toolbutton_find_in_titles") as ToggleToolButton;
		find_in_titles.toggled.connect (find_in_toggled);

		search = builder.get_object ("entry_search") as Entry;
		search.changed.connect (search_changed);

		show_stats = builder.get_object ("toolbutton_show_stats") as ToolButton;
		show_stats.clicked.connect (show_stats_clicked);

		sw_treeview = builder.get_object ("scrolledwindow_treeview") as ScrolledWindow;
		treeview = builder.get_object ("treeview_results") as TreeView;
		sw_iconview = builder.get_object ("scrolledwindow_iconview") as ScrolledWindow;
		iconview = builder.get_object ("iconview_results") as IconView;
		setup_ui_results (treeview, iconview);

		view_list.set_active (true);
	}

	private void setup_ui_results (TreeView treeview, IconView iconview) {
		// Setup treeview
		store = new ListStore (8,
		                       typeof (Gdk.Pixbuf),  // Icon small
		                       typeof (Gdk.Pixbuf),  // Icon big
		                       typeof (string),      // URN
		                       typeof (string),      // URL
		                       typeof (string),      // File name
		                       typeof (string),      // File last changed
		                       typeof (string),      // File size
		                       typeof (string));     // Tooltip
		treeview.set_model (store);
		treeview.set_tooltip_column (7);

		var col = new Gtk.TreeViewColumn ();

		var renderer1 = new CellRendererPixbuf ();
		col.pack_start (renderer1, false);
		col.add_attribute (renderer1, "pixbuf", 0);

		var renderer2 = new Tracker.CellRendererText ();
		col.pack_start (renderer2, true);
		col.add_attribute (renderer2, "text", 4);

		col.set_title ("File");
		col.set_resizable (true);
		col.set_expand (true);
		col.set_sizing (Gtk.TreeViewColumnSizing.AUTOSIZE);
		treeview.append_column (col);

		treeview.insert_column_with_attributes (-1, "Last Changed", new CellRendererText (), "text", 5, null);
		treeview.insert_column_with_attributes (-1, "Size", new CellRendererText (), "text", 6, null);
		treeview.row_activated.connect (view_row_selected);

		// Setup iconview
		iconview.set_model (store);
		iconview.set_item_width (96);
		iconview.set_selection_mode (Gtk.SelectionMode.SINGLE);
		iconview.set_pixbuf_column (1);
		iconview.set_text_column (4);
		//iconview.row_activated += view_row_selected;
	}

	private void search_changed (Editable editable) {
		if (last_search_id != 0) {
			Source.remove (last_search_id);
		}

		last_search_id = Timeout.add_seconds (1, search_run);
	}

	private bool search_run () {
		last_search_id = 0;

		Tracker.Query query = new Tracker.Query ();
		Tracker.Sparql.Cursor cursor = null;

		query.limit = 100;
		query.criteria = search.get_text ();

		if (find_in_contents.active) {
			cursor = query.perform (query.Type.ALL);
		} else {
			cursor = query.perform (query.Type.ALL_ONLY_IN_TITLES);
		}

		if (cursor == null) {
			// FIXME: Print "no results" some where
			return false;
		}

		store.clear ();

		var screen = window.get_screen ();
		var theme = IconTheme.get_for_screen (screen);

		try {
			while (cursor.next()) {
				int i;

				for (i = 0; i < cursor.n_columns; i++) {
					if (i == 0) {
						debug ("--> %s", cursor.get_string (i));
					} else {
						debug ("  --> %s", cursor.get_string (i));
					}
				}
				debug ("\n");

				// Get icon
				string urn = cursor.get_string (0);
				string _file = cursor.get_string (1);
				string title = cursor.get_string (2);
				string _file_time = cursor.get_string (3);
				string _file_size = cursor.get_string (4);
				string tooltip = cursor.get_string (7);
				Gdk.Pixbuf pixbuf_small = tracker_pixbuf_new_from_file (theme, _file, size_small);
				Gdk.Pixbuf pixbuf_big = tracker_pixbuf_new_from_file (theme, _file, size_big);
				string file_size = GLib.format_size_for_display (_file_size.to_int());
				string file_time = tracker_time_format_from_iso8601 (_file_time);

				// Insert into model
				TreeIter iter;
				store.append (out iter);

				// FIXME: should optimise this a bit more, inserting 2 images into a list eek
				store.set (iter,
					       0, pixbuf_small,
					       1, pixbuf_big,
					       2, urn,
					       3, _file,
					       4, title,
					       5, file_time,
					       6, file_size,
					       7, tooltip,
					       -1);
			}
		} catch (GLib.Error e) {
			warning ("Could not iterate query results: %s", e.message);
			return false;
		}

		return false;
	}

	private void view_toggled () {
		bool rows;

		rows = view_list.active || view_details.active;
		
		if (current_view == rows) {
			return;
		}

		if (rows) {
			// FIXME: if list/details changes, re-run query
			sw_iconview.hide ();
			sw_treeview.show_all ();
			debug ("View toggled to 'list' or 'details'");
		} else {
			sw_iconview.show_all ();
			sw_treeview.hide ();
			debug ("View toggled to 'icons'");
		}

		current_view = rows;
	}

	private void find_in_toggled () {
		if (current_find_in == find_in_contents.active) {
			return;
		}

		if (find_in_contents.active) {
			debug ("Find in toggled to 'contents'");
			search_run ();
		} else {
			debug ("Find in toggled to 'titles'");
			search_run ();
		}

		current_find_in = find_in_contents.active;
	}

	private void view_row_selected (TreeView view, TreePath path, TreeViewColumn column) {
		TreeIter iter;

		var model = view.get_model ();
		model.get_iter (out iter, path);

		weak string uri;
		model.get (iter, 3, out uri);

		debug ("Selected uri:'%s'", uri);

		try {
			AppInfo.launch_default_for_uri (uri, null);
		} catch (GLib.Error e) {
			warning ("Could not launch application: " + e.message);
		}
	}

	private void show_stats_clicked () {
		debug ("Showing stats dialog");
		TrackerStats s = new TrackerStats ();
		s.show ();
	}
}

static int main (string[] args) {
	Gtk.init (ref args);

	Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
	Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain (Config.GETTEXT_PACKAGE);

	TrackerNeedle n = new TrackerNeedle ();
	n.show();
	Gtk.main ();

	return 0;
}
