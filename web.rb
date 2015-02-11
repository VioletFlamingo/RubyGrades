require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'json'
###
require "rubygems"
require "google/api_client"
require "google_drive"

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/todo_list.db")
  class User
	  include DataMapper::Resource
	  property :id, Serial
	  property :login, Text, :required => true, :unique => true, :length => 2..12
	  property :password, Text, :required => true, :length => 5..20
	  property :name, Text, :required => true, :length => 2..50
	  property :surname, Text, :required => true, :length => 2..50
  end
DataMapper.finalize.auto_upgrade!

enable :sessions

#############
loggedToGoolge = false

# Authorizes with OAuth and gets an access token.
client = Google::APIClient.new
auth = client.authorization
auth.client_id = "521880635248-j3fhsnu48hkj70fmn9bp0v2sg57nc31l.apps.googleusercontent.com"
auth.client_secret = "O8Qrl_rEk1TpZD68k9qwWSCW"
auth.scope =
    "https://www.googleapis.com/auth/drive " +
    "https://spreadsheets.google.com/feeds/"
auth.redirect_uri = "https://www.example.com/oauth2callback"
print("1. Open this page:\n%s\n\n" % auth.authorization_uri)
print("2. Enter the authorization code shown in the page: ")
auth.code = $stdin.gets.chomp
auth.fetch_access_token!
access_token = auth.access_token

# Creates a session.
googlesession = GoogleDrive.login_with_oauth(access_token)

login = "jkowal"

spreadsheets = googlesession.spreadsheet_by_key("1fOq7Kuvc7kQb5EUipcRPYKIHuGmuhJl7fquAwVKfcrA")
num_worksheets = spreadsheets.worksheets.size

loggedToGoolge = true

#############

get '/?' do
  erb :index
end

post '/?' do
  if params.has_key?("log")
    item = User.first(:login => params[:login], :password => params[:password])
    unless item.nil?
    	session[:message] = params[:login]
    	redirect '/home'
    else 
    	session[:message] = []
    	session[:message] << ["Bledny login lub haslo"]
    	redirect '/error'
    end
  else
    redirect '/new'
  end
end

get '/new/?' do
  erb :new
end


post '/new/?' do
  new_user = User.new(:login => params[:login], :password => params[:password], :name => params[:name], 
  	   :surname => params[:surname])
  if new_user.save
    redirect '/'
  else
  	err_message = []
    new_user.errors.each do |e|
    	err_message << e
    end
    p err_message
    session[:message] = err_message
    redirect '/error'
  end
end

get '/home/?' do
	@item = User.first(:login => session[:message])

	@subjects = []
	@grades = []
	@avgs = []
	@headings = []
	@num_subjects = 0
	###
	for sheet in 0...num_worksheets
		ws = spreadsheets.worksheets[sheet]
		# Dumps all cells.
		for row in 1..ws.num_rows
			sum = 0
			if (ws[row, 1]==session[:message])
		  		for col in 1..ws.num_cols
		    		p ws[row, col]
		    		if col!=0 
		    			sum+=ws[row, col].to_f
		    		end
		    	end
		    	@grades << ws.rows[row-1]
		    	@subjects << ws.title
		    	@avgs << sum/(ws.num_cols-1)
		    	@headings << ws.rows[0]
		    	@num_subjects+=1
		  	end
		end
	end

	p @subjects
	p @grades
	p @num_subjects
	p @avgs
	p @headings
	###

	erb :home
end

get '/error/?' do
	@errors_occured = session[:message]
	erb :error
end

post '/error/?' do
	redirect '/'
end