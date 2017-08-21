require 'sinatra'
require 'json'

def here
  File.expand_path '..', __FILE__
end


enable :sessions

password = "aoeusnth"

get '/' do
  erb :index, :locals => {:photoStore =>  File.read(File.join(here, 'photos.json'))}
end

before '/upload' do
  if session['loggedIn'] == true
    :nil
  else
    redirect to('/login')
  end
end

get '/upload' do
  erb :upload
end

post '/upload' do
  unless params['file'] &&
         (tmpfile = params['file'][:tempfile]) &&
         (filename = params["file"]["filename"]) &&
         (caption = params["caption"])
    @error = "No file selected"
    return erb :upload
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
def initialPhotoStore
  {
    :photos => []
  }
end
  params.inspect
end


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

get '/logout' do
  session['loggedIn'] = false
  redirect to("/")
end

# HELPERS
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
