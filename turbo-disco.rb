require 'sinatra'
require 'json'

# Sinatra Config
enable :sessions

# App Config
password = File.read("password.txt").strip

###########################
# Routes
###########################
#
# Root
#
get '/' do
  erb :index, :locals => {:photoStore =>  File.read(File.join(here, 'photos.json'))}
end

#
# Upload
#
before '/upload' do
  unless loggedIn?
    redirect to('/login')
  end
end

get '/upload' do
  erb :upload
end

post '/upload' do
  unless params['file'] &&
         (tmpfile = params['file'][:tempfile]) &&
         (filename = params['file'][:filename].gsub(/\s/, '-')) &&
         (caption = params["caption"])
    return "There was an error processing the upload"
  end
  # Write the temp file
  while blk = tmpfile.read(65536)
    File.open("./public/originals/#{filename}", 'a') { |file| file.write(blk) }
  end
  # Do the resizing
  `convert public/originals/#{filename}  -resize 800x800  public/resized_800/#{filename}`
  # Add it to the JSON file
  photoStore = readPhotoStore
  photoStore["photos"] = photoStore["photos"].push(
      {:original => "originals/#{filename}",
       :resized_800 => "resized_800/#{filename}",
       :caption => caption
      }
    )
  savePhotoStore photoStore
  erb :upload
end

#
# Login
#
get '/login' do
  if loggedIn?
    redirect to("/")
  else
    erb :login
  end
end

post '/login' do
  if params['password'] == password
    session['loggedIn'] = true
    redirect to("/upload")
  else
    erb :login
  end
end

#
# Logout
#
get '/logout' do
  session['loggedIn'] = false
  redirect to("/")
end

###########################
# HELPERS
###########################
def loggedIn?
  session['loggedIn'] == true
end

def readPhotoStore
  begin
    JSON.parse File.read File.join(here, 'photos.json')
  rescue
    initialPhotoStore
  end
end

def savePhotoStore(photoStore)
  File.open(File.join(here, "photos.json"),"w") do |f|
    f.write photoStore.to_json
  end
end

def initialPhotoStore
  { "photos" => []
  }
end

def here
  File.expand_path '..', __FILE__
end
