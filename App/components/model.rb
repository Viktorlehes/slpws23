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
  return db.execute("SELECT * FROM users WHERE username=?", username).first
end

def createUser(username, password, passwordConfirm)
  db = connectToDb()
  userId = getUserByUsername(username)

  if username.empty? or password.empty?
    session.delete("error")
    session[:error] = "Please fill in all fields"
    redirect("/register")
  end

  if userId
    session.delete("error")
    session[:error] = "User already exists"
    redirect("/register")
  end

  if password != passwordConfirm
    session.delete("error")
    session[:error] = "Confirmation password is incorrect"
    redirect("/register")
  end

  passwordDigest = BCrypt::Password.create(password)
  db.execute(
    "INSERT INTO users (username, passwordDigest) VALUES (?, ?);",
    [username.downcase, passwordDigest]
  )
  redirect("/login")
end

def loginUser(username, password)
  db = connectToDb()
  user = db.execute(
    "SELECT * FROM users WHERE username = ?;",
    [username]
  ).first

  if user.empty?
    session.delete("error")
    session[:error] = "wrong username or password"
    redirect("/login")
  end

  userId = user["userId"]
  passwordDigest = user["passwordDigest"]

  if BCrypt::Password.new(passwordDigest) != password
    session[:error] = "wrong username or password"
    redirect("/login")
  end

  session[:loggedIn] = userId
  p session[:loggedIn]
  redirect("/featured")
end

def getCityCordinatesFromSearch(cityName)
  uri = URI("http://api.openweathermap.org/geo/1.0/direct?q=#{cityName}&limit=5&appid=9e23271195b29b37c3bac4c4457487cf")
  response = Net::HTTP.get(uri)
  weatherData = JSON.parse(response)
  latitude = weatherData[1]["lat"]
  longitude = weatherData[1]["lon"]
  return latitude, longitude unless weatherData == nil
end

def getWeatherDataByCordinates(lon, lat)
  start_time = Time.now

  uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{lon}&lon=#{lat}&units=metric&appid=8ff21487fbf05de0ac8a7e46b7643b72")

  response = Net::HTTP.get(uri)

  weatherData = JSON.parse(response)

  end_time = Time.now
  completionTime = end_time - start_time
  return weatherData, completionTime
end

def getStandardWeatherData()
  db = connectToDb()

  standard_dashboard_cities = db.execute(
    "SELECT name, lon, lat FROM location"
  )
  # [{"name"=>"sundsvall", "lon"=>62.383354, "lat"=>17.299768},
  #  {"name"=>"gothenburg", "lon"=>40.9277324, "lat"=>-100.1619896},
  #  {"name"=>"lund", "lon"=>55.6932601, "lat"=>13.320832},
  #  {"name"=>"stockholm", "lon"=>59.3371186, "lat"=>17.9860453},
  #  {"name"=>"halmstad", "lon"=>56.6999786, "lat"=>12.8668829},
  #  {"name"=>"karlstad", "lon"=>59.516667, "lat"=>13.8}]

  standard_dashboard_data = []

  standard_dashboard_cities.each do |city|
    uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{city["lon"]}&lon=#{city["lat"]}&units=metric&appid=8ff21487fbf05de0ac8a7e46b7643b72")

    response = Net::HTTP.get(uri)

    weatherData = JSON.parse(response)

    standard_dashboard_data << weatherData
  end

  return standard_dashboard_data
end
