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

using Tracker.Sparql;

public class Tracker.Query {
	public enum Type {
		ALL,
		ALL_ONLY_IN_TITLES,
		MUSIC
	}

	public string criteria { get; set; }
	public uint offset { get; set; }
	public uint limit { get; set; }
	public string query { get; private set; }

	private static Sparql.Connection connection;

	public Query () {
		try {
			connection = Sparql.Connection.get ();
		} catch (Sparql.Error e) {
			warning ("Could not get Sparql connection: %s", e.message);
		}
	}

	public Sparql.Cursor? perform (Type query_type)
	requires (connection != null) {
		Sparql.Cursor cursor = null;

		if (criteria == null || criteria.length < 1) {
			warning ("Criteria was NULL or an empty string, no query performed");
			return null;
		}

		if (limit < 1) {
			warning ("Limit was < 1, no query performed");
			return null;
		}

		string criteria_escaped = tracker_sparql_escape_string (criteria);

		switch (query_type) {
		case Type.ALL:
			query = @"SELECT ?u nie:url(?u) tracker:coalesce(nie:title(?u), nfo:fileName(?u), \"Unknown\") nfo:fileLastModified(?u) nfo:fileSize(?u) nie:url(?c) WHERE { ?u fts:match \"$criteria_escaped\" . ?u nfo:belongsToContainer ?c ; tracker:available true . } ORDER BY DESC(fts:rank(?u)) OFFSET 0 LIMIT 100";
			break;
			
		case Type.ALL_ONLY_IN_TITLES:
			query = @"SELECT ?u nie:url(?u) tracker:coalesce(nfo:fileName(?u), \"Unknown\") nfo:fileLastModified(?u) nfo:fileSize(?u) nie:url(?c) WHERE { ?u a nfo:FileDataObject ; nfo:belongsToContainer ?c ; tracker:available true . FILTER(fn:contains(nfo:fileName(?u), \"$criteria_escaped\")) } ORDER BY DESC(nfo:fileName(?u)) OFFSET 0 LIMIT 100";
			break;

		case Type.MUSIC:
			break;

		default:
			assert_not_reached ();
		}

		debug ("Running query: '%s'", query);

		try {
			cursor = connection.query (query, null);
		} catch (Sparql.Error ea) {
			warning ("Could not run Sparql query: %s", ea.message);
		} catch (GLib.IOError eb) {
			warning ("Could not run Sparql query: %s", eb.message);
		}

		return cursor;
	}
}
