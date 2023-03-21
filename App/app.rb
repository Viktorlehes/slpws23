require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "rerun"
require "net/http"
require "active_support"
require_relative "components/model.rb"

# var tydlig i dok.

set :port, 3000

key = SecureRandom.hex(32)
enable :sessions
set :session_secret, key
set :sessions, :expire_after => 2592000

helpers do
  def link_css(path)
    css_path = "#{path}"
    @stylesheet_paths << css_path unless @stylesheet_paths.include?(css_path)
  end

  def value(key)
    @values&.fetch(key, "")
  end
end

before do
  @stylesheet_paths = []
  protectedRoutes = ["/dashboard", "/featured"]
  adminRoutes = ["/overview"]
  if protectedRoutes.include?(request.path_info)
    if !session[:loggedIn]
      redirect("/auth")
    end
  end
  if adminRoutes.include?(request.path_info)
    if !session[:admin]
      redirect("/auth")
    end
  end
end

get("/") { redirect("/auth") }

get("/auth") do
  if session[:error]
    error = session[:error]
  else
    error = nil
  end

  if session[:values]
    @values = session[:values]
  else
    @values = nil
  end

  if session[:loggedIn]
    session.delete("loggedIn")
  end

  slim(:"auth/auth", :layout => :"layouts/layout_registration", locals: { error: error })
end

post("/register") do
  username, password, passwordConfirm = params[:username_register].downcase, params[:password_register], params[:"passwordConfirm"]
  status = createUser(username, password, passwordConfirm)

  session[:values] = { username_register: params[:username_register], password_register: params[:password_register], password_confirm: params[:passwordConfirm] }

  redirect("auth")
end

post("/login") do
  username = params[:username].downcase
  password = params[:password]

  status = loginUser(username, password)

  session[:values] = { username: params[:username], password: params[:password] }

  if status == 200
    redirect("featured")
  else
    redirect("auth?login=true")
  end
end

get("/logout") do
  session.clear
  redirect("/auth")
end

get("/featured") do
  standardDashboardData = getStandardWeatherData()
  optimizedStandardDashboardData = optimizeTempforArray(standardDashboardData)
  selectedCity = session[:selectedCity] || "gothenburg"
  selectedCityData = optimizedStandardDashboardData.find { |index| index["name"].downcase == selectedCity } || optimizedStandardDashboardData[1]

  role = session[:admin]
  slim(:"main/featured", :layout => :"layouts/layout_main", locals: { dashboard_data: optimizedStandardDashboardData, selectedCityData: selectedCityData, role: role })
end

post("/featured-selected-city") do
  selectedCity = params[:selected].downcase
  session[:selectedCity] = selectedCity
  redirect("/featured")
end

get("/dashboard") do
  if params["city"]
    lon, lat, status = getCityCordinatesFromSearch(params["city"])
    if status == 200
      dashboardWeatherData = getWeatherDataByCordinates(lon, lat)
      dashboardWeatherData["status"] = 200
      dashboardWeatherData = optimizeTempForHash(dashboardWeatherData)
    else
      dashboardWeatherData = {}
      dashboardWeatherData["status"] = 400
    end
  else
    dashboardWeatherData = getGothenburgWeather()
    dashboardWeatherData["status"] = 200
    dashboardWeatherData = optimizeTempForHash(dashboardWeatherData)
  end

  db = connectToDb()

  saved_locations = db.execute("SELECT name FROM location INNER JOIN ulr ON ulr.locationid = location.id WHERE ulr.userid = ?", [session[:loggedIn]])

  role = session[:admin]
  slim(:"main/dashboard", :layout => :"layouts/layout_main", locals: { dashboardWeahterData: dashboardWeatherData, savedLocations: saved_locations, role: role })
end

post("/dashboard") do
  session["searchedCity"] = params["searchedCity"].downcase
  redirect("/dashboard?city=#{session["searchedCity"]}")
end

post("/dashboard-save-city") do
  saved_city = params["city-save"].downcase

  db = connectToDb()

  city_data = db.execute("INSERT INTO location(name) VALUES($1) 
                         ON CONFLICT(name) DO UPDATE SET name=excluded.name 
                         RETURNING id", saved_city)

  city_id = city_data[0]["id"]

  db.prepare("INSERT OR IGNORE INTO ulr(locationId, userId) VALUES ($1, $2)").execute(city_id, session[:loggedIn])

  redirect("/dashboard?city=#{saved_city}")
end

post("/dashboard-selected-city") do
  intent_select = params["selected-city-select"]
  intent_delete = params["selected-city-delete"]

  if intent_select
    selected_city = params["selected-city-select"]

    redirect("/dashboard?city=#{selected_city}")
  end

  if intent_delete
    selected_city = params["selected-city-delete"]

    db = connectToDb()

    location_id_data = db.execute("SELECT id FROM location WHERE name = $1", selected_city)
    location_id = location_id_data[0]["id"]

    db.prepare("DELETE FROM ulr WHERE locationId = $1 AND userId = $2").execute(location_id, session[:loggedIn])

    redirect("/dashboard?city=gothenburg")
  end

  redirect("/dashboard")
end

get("/overview") do
  role = session[:admin]

  users = getAllUsers()

  slim(:"main/overview", :layout => :"layouts/layout_main", locals: { role: role, users: users })
end

post("/overview/edit/:userId") do |userId|
  if params["username-edit"]
    new_username = params["username-edit"].downcase.strip
    if new_username != ""
      if session[:admin]
        updateUsername(userId, new_username)
      end
    end
  end

  if params["selected-auth"]
    new_role = params["selected-auth"]
    if session[:admin]
      updateRole(userId, new_role)
    end
  end

  if params["delete-user"]
    if session[:admin]
      deleteUser(userId)
    end
  end

  redirect("/overview")
end

post("/overview/delete/:userId") do |userId|
  if session[:admin]
    db = connectToDb()
    db.execute("DELETE FROM ulr WHERE userId = ?", [userId])
    db.execute("DELETE FROM users WHERE userId = ?", [userId])
  end
  redirect("/overview")
end
