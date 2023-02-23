require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "rerun"
require "net/http"
require_relative "components/model.rb"

set :port, 3000

enable :sessions

before do
  protectedRoutes = ["/dashboard", "/featured"]

  if protectedRoutes.include?(request.path_info)
    if !session[:loggedIn]
      redirect("/login")
    end
  end
end

get("/") do
  redirect("/login")
end

get("/register") do
  if session[:error]
    error = session[:error]
  else
    error = nil
  end

  slim(:register, locals: { error: error })
end

post("/register") do
  username, password, passwordConfirm = params[:username], params[:password], params[:"passwordConfirm"]
  createUser(username, password, passwordConfirm)
end

get("/login") do
  if session[:error]
    error = session[:error]
  else
    error = nil
  end

  slim(:login, locals: { error: error })
end

post("/login") do
  username = params[:username].downcase.to_s
  password = params[:password].to_s

  loginUser(username, password)
end

get("/logout") do
  session.clear
  redirect("/login")
end

get("/dashboard") do
  slim(:foo)
end

get("/featured") do
  standard_dashboard_data = getStandardWeatherData()

  if session[:selectedCity]
    selectedCity = session[:selectedCity]
  else
    selectedCity = "gothenburg"
  end

  if selectedCity != "gothenburg"
    standard_dashboard_data.each do |index|
      nameOfCity = index["name"]
      if nameOfCity = selectedCity
        selectedCityData = index
      end
    end
  else
    selectedCityData = standard_dashboard_data[1]
  end

  p selectedCityData

  # mtemp = selectedCityData["main"]["temp"]
  # feels = selectedCityData["main"]["feels_like"]
  # humidity = selectedCityData["main"]["humidity"]
  # description = selectedCityData["weather"][0]["description"]

  slim(:"dashboard", locals: { standard_dashboard_data: standard_dashboard_data, selectedCityData: selectedCityData })
end

post("/featured-selected-city") do
  selectedCity = params[:selected]
  session[:selectedCity] = selectedCity
  redirect("/featured")
end
