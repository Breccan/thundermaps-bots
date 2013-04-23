require 'sqlite3'

begin

    db = SQLite3::Database.new "history.db"
	version = db.get_first_value 'SELECT SQLITE_VERSION()'
    puts "Using SQLite3 version: " + version
	
	db.execute "DROP TABLE Records"
	db.execute "CREATE TABLE Records(ID INTEGER PRIMARY KEY, library_name TEXT, latitude REAL, longitude REAL, occurred_on TEXT, description TEXT, category_name TEXT, source_id TEXT)"

	puts "TABLE Records created"
	
	db.execute "CREATE TABLE Files(ID INTEGER PRIMARY KEY, url TEXT)"
	puts "TABLE Files created"
	
	
rescue SQLite3::Exception => e 
    
    puts "Exception occured"
    puts e
    
ensure
    db.close if db
end