require "net/http"
require "sinatra"
require "sqlite3"

# Använde denna klassen för att spara alla kondinaterna till städerna jag ville hamed i appen i databasen

# tänkte i början att jag skulle bara anväda dem städerna som jag hade på databasen, men gjorde annorlunda 

class Location 
    def initialize(name)
        @name = name
        @db = SQLite3::Database.new("db/new.db")
        @db.results_as_hash = true
    end

    def lonlat()
        location = @name
        uri = URI("http://api.openweathermap.org/geo/1.0/direct?q=#{location}&limit=5&appid=9e23271195b29b37c3bac4c4457487cf")
        response = Net::HTTP.get(uri)
        weatherData = JSON.parse(response)
        @latitude = weatherData[1]["lat"]
        @longitude = weatherData[1]["lon"]

        if @longitude and @latitude
            @db.execute(
                "INSERT INTO location (lon, lat, name) VALUES (?, ?, ?);",
                [@latitude, @longitude, @name]
            )
        else 
            alert("could not get information")
        end 
    end
end

p Location.new("lerum").lonlat()