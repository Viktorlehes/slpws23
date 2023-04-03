require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "net/http"

# Module Model
module Model
  # Connect to SQLite3 database and return database object
  #
  # @return [SQLite3::Database] SQLite3 database object
  def connectToDb()
    db = SQLite3::Database.new("db/new.db")
    db.results_as_hash = true
    return db
  end

  # Get user object from SQLite3 database by username
  #
  # @param [String] username The username of the user
  # @return [Hash, nil] A hash representing the user, or nil if not found
  def getUserByUsername(username)
    db = connectToDb()
    user = db.execute("SELECT * FROM users WHERE username=?", username).first || nil
    return user
  end

  # Create a new user in SQLite3 database
  #
  # @param [String] username The username of the user
  # @param [String] password The password of the user
  # @param [String] passwordConfirm The confirmation password of the user
  # @return [Integer] HTTP status code indicating success or error
  def createUser(username, password, passwordConfirm)
    db = connectToDb()
    user = getUserByUsername(username)
    status = 200
    standardRole = "standard"
    session.clear

    if username.empty? or password.empty?
      session.delete("error")
      session[:error] = "Please fill in all fields"
      return status = 400
    end

    if user
      session.delete("error")
      session[:error] = "User already exists"
      return status = 400
    end

    if password != passwordConfirm
      session.delete("error")
      session[:error] = "Confirmation password is incorrect"
      return status = 400
    end

    passwordDigest = BCrypt::Password.create(password)
    db.execute(
      "INSERT INTO users (username, passwordDigest, auth) VALUES (?, ?, ?);",
      [username.downcase, passwordDigest, standardRole]
    )
    return status
  end

  # Verify user credentials and login
  #
  # @param [String] username The username of the user
  # @param [String] password The password of the user
  # @return [Integer] HTTP status code indicating success or error
  def loginUser(username, password)
    db = connectToDb()
    user = getUserByUsername(username)
    status = 200
    session.clear

    if password == "" || username == ""
      session[:error] = "please fill in all required fields"
      return status = 400
    end

    if !user
      session[:error] = "wrong username or password"
      return status = 400
    end

    passwordDigest = user["passwordDigest"]

    if BCrypt::Password.new(passwordDigest) != password
      session[:error] = "wrong username or password"
      return status = 400
    end

    # token = BCrypt::Password.create(user["userId"])

    if user["auth"] == "admin"
      session[:admin] = true
    else
      session[:admin] = false
    end

    session[:loggedIn] = user["userId"]

    return status
  end

  # Get the latitude and longitude of a city from OpenWeatherMap API
  #
  # @param [String] cityName The name of the city to search for
  # @return [Float, Float, Integer] The latitude and longitude of the city, or nil if not found, and HTTP status code indicating success or error
  def getCityCordinatesFromSearch(cityName)
    status = 200

    if cityName.include?(" ")
      searchedCity = cityName.split(" ")[0]
    else
      searchedCity = cityName
    end

    uri = URI("http://api.openweathermap.org/geo/1.0/direct?q=#{searchedCity}&limit=5&appid=9e23271195b29b37c3bac4c4457487cf")
    response = Net::HTTP.get(uri)
    weatherData = JSON.parse(response)

    p weatherData

    if weatherData == nil || weatherData == []
      return latitude = nil, longitude = nil, status = 400
    end
    latitude = weatherData[1]["lat"]
    longitude = weatherData[1]["lon"]
    return latitude, longitude, status
  end

  # Get weather data for a location from OpenWeatherMap API
  #
  # @param [Float] lon The longitude of the location
  # @param [Float] lat The latitude of the location
  # @return [Hash] A hash representing the weather data for the location
  def getWeatherDataByCordinates(lon, lat)
    uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{lon}&lon=#{lat}&units=metric&appid=8ff21487fbf05de0ac8a7e46b7643b72")

    response = Net::HTTP.get(uri)

    weatherData = JSON.parse(response)

    return weatherData
  end

  # Get weather data for a list of cities from SQLite3 database
  #
  # @return [Array<Hash>] An array of hashes representing the weather data for each city
  def getStandardWeatherData()
    db = connectToDb()

    standard_dashboard_cities = db.execute(
      "SELECT name, lon, lat FROM location"
    )

    standard_dashboard_data = []

    standard_dashboard_cities.each do |city|
      if city["name"] == "sundsvall kommun" or city["name"] == "gothenburg" or city["name"] == "lund municipality" or city["name"] == "stockholm" or city["name"] == "halmstad" or city["name"] == "karlstad"
        uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{city["lon"]}&lon=#{city["lat"]}&units=metric&appid=8ff21487fbf05de0ac8a7e46b7643b72")

        response = Net::HTTP.get(uri)

        weatherData = JSON.parse(response)

        standard_dashboard_data << weatherData
      end
    end

    return standard_dashboard_data
  end

  # Get weather data for Gothenburg, Sweden from OpenWeatherMap API
  #
  # @return [Hash] A hash representing the weather data for Gothenburg, Sweden
  def getGothenburgWeather()
    weatherData = getWeatherDataByCordinates(40.9277324, -100.1619896)
    return weatherData
  end

  def optimizeTempforArray(standardDashboardData)
    roundedDashboardData = standardDashboardData

    roundedDashboardData.each do |data|
      realTemp = data["main"]["temp"].round(0)
      feelsLike = data["main"]["feels_like"].round(0)
      data["main"]["temp"] = realTemp
      data["main"]["feels_like"] = feelsLike
    end
    return roundedDashboardData
  end

  # Round the temperature values in an array of weather data
  #
  # @param [Array<Hash>] standardDashboardData An array of hashes representing weather data for each location
  # @return [Array<Hash>] The same array of weather data, with temperature values rounded
  def optimizeTempforArray(standardDashboardData)
    roundedDashboardData = standardDashboardData

    roundedDashboardData.each do |data|
      realTemp = data["main"]["temp"].round(0)
      feelsLike = data["main"]["feels_like"].round(0)
      data["main"]["temp"] = realTemp
      data["main"]["feels_like"] = feelsLike
    end
    return roundedDashboardData
  end

  # Round the temperature values in a single hash of weather data
  #
  # @param [Hash] data A hash representing the weather data for a single location
  # @return [Hash] The same hash of weather data, with temperature values rounded
  def optimizeTempForHash(data)
    realTemp = data["main"]["temp"].round(0)
    feelsLike = data["main"]["feels_like"].round(0)
    data["main"]["temp"] = realTemp
    data["main"]["feels_like"] = feelsLike
    return data
  end

  # Get a list of all users from SQLite3 database
  #
  # @return [Array<Hash>] An array of hashes representing each user
  def getAllUsers()
    db = connectToDb()
    users = db.execute("SELECT * FROM users")
    return users
  end

  def updateRole(userId, new_role)
    db = connectToDb()

    db.execute("UPDATE users SET auth = ? WHERE userId = ?", [new_role, userId])

    return nil
  end

  def updateUsername(userId, new_username)
    db = connectToDb()

    db.execute("UPDATE users SET username = ? WHERE userId = ?", [new_username, userId])

    return nil
  end

  # Update the role of
  # Update the role of a user in SQLite3 database
  #
  # @param [Integer] userId The ID of the user to update
  # @param [String] new_role The new role of the user
  # @return [nil] Returns nil
  def updateRole(userId, new_role)
    db = connectToDb()

    db.execute("UPDATE users SET auth = ? WHERE userId = ?", [new_role, userId])

    return nil
  end

  # Update the username of a user in SQLite3 database
  #
  # @param [Integer] userId The ID of the user to update
  # @param [String] new_username The new username of the user
  # @return [nil] Returns nil
  def updateUsername(userId, new_username)
    db = connectToDb()

    db.execute("UPDATE users SET username = ? WHERE userId = ?", [new_username, userId])

    return nil
  end
end
