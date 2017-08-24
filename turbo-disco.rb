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
before '/admin/*' do
  unless loggedIn?
    redirect to('/login')
  end
end

get '/admin/upload' do
  erb :upload
end

post '/admin/upload' do
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
  photoStore["photos"] = photoStore["photos"].unshift(
      {:original => "originals/#{filename}",
       :resized_800 => "resized_800/#{filename}",
       :caption => caption
      }
    )
  savePhotoStore photoStore
  erb :upload
end

#
# Edit
#
get '/admin/edit' do
  erb :edit, :locals => {
    :photoStore => File.read(File.join(here, 'photos.json')),
    :message => nil
  }
end

post '/admin/edit' do
  photoStoreJson = params['photoStore']
  begin
    photoStore = JSON.parse photoStoreJson
    savePhotoStore photoStore
    erb :edit, :locals => {:photoStore => photoStoreJson, :message => "Saved"}
  rescue
    erb :edit, :locals => {
      :photoStore => photoStoreJson,
      :message => "There was a problem saving the Photo Store"
    }
  end
end

#
# Login
#
get '/login' do
  if loggedIn?
    redirect to("/admin/upload")
  else
    erb :login
  end
end

post '/login' do
  if params['password'] == password
    session['loggedIn'] = true
    redirect to("/admin/upload")
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

#
# Git Status
#

get '/admin/status' do
  status = `git status`
  diff = `git diff`
  erb :status, :locals => {:status => toBr(status), :diff => toBr(diff)}
end

#
# Save to git
#
get '/admin/save' do
  message = params['message'] || "Commit from web interface."
  add = `git add . -v`
  commit = `git commit -m"#{message}" -v`
  push = `git push -v`
  erb :save, :locals => {:add => toBr(add), :commit => toBr(commit), :push => toBr(push)}
end

#
# Update from git
#
get '/admin/update' do
  pull = `git pull -v`
  erb :pull, :locals => {:pull => pull}
end

#
# Restart
#
get '/admin/restart' do
  `touch tmp/restart.txt`
  "Restart attempted"
end

get '/stats' do
  "#{readPhotoStore['photos'].length} photos"
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
    f.write JSON.pretty_generate(photoStore)
  end
end

def initialPhotoStore
  { "photos" => []
  }
end

def here
  File.expand_path '..', __FILE__
end

def toBr(str)
  str.gsub(/(?:\n\r?|\r\n?)/, '<br>')
end
