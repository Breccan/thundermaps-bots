require 'sqlite3'

begin

    db = SQLite3::Database.new "bot.db"
	version = db.get_first_value 'SELECT SQLITE_VERSION()'
    puts "Using SQLite3 version: " + version
	
	db.execute "CREATE TABLE Records(ID INTEGER PRIMARY KEY, latitude REAL, longitude REAL, occurred_on DATE, description TEXT, category_name TEXT, source_id TEXT)"
    puts "TABLE Records created"
	
	
rescue SQLite3::Exception => e 
    
    puts "Exception occured"
    puts e
    
ensure
    db.close if db
end