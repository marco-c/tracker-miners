/* Tracker
 * Copyright (C) 2005, Mr Jamie McCracken
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef _TRACKER_DB_H_
#define _TRACKER_DB_H_

#include <glib.h>
#include "tracker-utils.h"
#include "config.h"

#ifdef USING_SQLITE
#include "tracker-db-sqlite.h"	
#else
#include "tracker-db-mysql.h"	
#endif
 
typedef enum {
	DATA_INDEX_STRING,
	DATA_STRING,
	DATA_NUMERIC,
	DATA_DATE
} DataTypes;

typedef struct {

	char		*id;
	DataTypes	type;
	gboolean	writeable;
	gboolean	embedded;
	
} FieldDef;


FileInfo *	tracker_db_get_file_info 	(DBConnection *db_con, FileInfo *info);
int		tracker_db_get_file_id	 	(DBConnection *db_con, const char* uri);
gboolean	tracker_is_valid_service 	(DBConnection *db_con, const char *service);
char *		tracker_db_get_id	 	(DBConnection *db_con, const char* service, const char *uri);
void		tracker_db_save_metadata 	(DBConnection *db_con, GHashTable *table, long file_id);
void		tracker_db_save_thumbs		(DBConnection *db_con, const char *small_thumb, const char *large_thumb, long file_id);
char **		tracker_db_get_files_in_folder 	(DBConnection *db_con, const char *folder_uri);
FieldDef *	tracker_db_get_field_def	(DBConnection *db_con, const char *field_name);
void		tracker_db_free_field_def 	(FieldDef *def);
gboolean	tracker_metadata_is_date 	(DBConnection *db_con, const char* meta);
FileInfo *	tracker_db_get_pending_file 	(DBConnection *db_con, const char *uri);
void		tracker_db_update_pending_file 	(DBConnection *db_con, const char* uri, int counter, TrackerChangeAction action);
void		tracker_db_insert_pending_file 	(DBConnection *db_con, long file_id, const char *uri, const char *mime, int counter, TrackerChangeAction action, gboolean is_directory);
gboolean	tracker_db_index_id_exists 	(DBConnection *db_con, unsigned int id);
gboolean	tracker_db_has_pending_files 	(DBConnection *db_con);
gboolean	tracker_db_has_pending_metadata	(DBConnection *db_con);
 
#endif
