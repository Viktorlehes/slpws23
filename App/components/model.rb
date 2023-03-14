require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "net/http"

def connectToDb()
  db = SQLite3::Database.new("db/new.db")
  db.results_as_hash = true
  return db
end

def getUserByUsername(username)
  db = connectToDb()
  user = db.execute("SELECT * FROM users WHERE username=?", username).first || nil
  return user
end

def createUser(username, password, passwordConfirm)
  db = connectToDb()
  user = getUserByUsername(username)
  status = 200
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
    "INSERT INTO users (username, passwordDigest) VALUES (?, ?);",
    [username.downcase, passwordDigest]
  )
  return status
end

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

  session[:loggedIn] = user["userId"]

  return status
end

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

def getWeatherDataByCordinates(lon, lat)
  uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{lon}&lon=#{lat}&units=metric&appid=8ff21487fbf05de0ac8a7e46b7643b72")

  response = Net::HTTP.get(uri)

  weatherData = JSON.parse(response)

  return weatherData
end

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

def optimizeTempForHash(data)
  realTemp = data["main"]["temp"].round(0)
  feelsLike = data["main"]["feels_like"].round(0)
  data["main"]["temp"] = realTemp
  data["main"]["feels_like"] = feelsLike
  return data
end
