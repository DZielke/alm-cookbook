require 'securerandom'
require 'yaml'

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# Generate new password for MySQL root unless it has already been stored in database.yml 
# This has to go before the include_recipe for mysql::server
if File.exists? "/vagrant/config/database.yml"
  stored_password = YAML.load_file("/vagrant/config/database.yml")["test"]["password"]
  node.set['mysql']['server_root_password'] = stored_password
else
  # create new database.yml
  node.set['mysql']['server_root_password'] = secure_password 
  template "/vagrant/config/database.yml" do
    source 'database.yml.erb'
    owner 'root'
    group 'root'
    mode 0644
  end
end

include_recipe "mysql::server"

# Create default CouchDB database
execute "create CouchDB database #{node[:couchdb][:database]}" do
  command "curl -X DELETE http://#{node[:couchdb][:host]}:#{node[:couchdb][:port]}/#{node[:couchdb][:database]}/"
  command "curl -X PUT http://#{node[:couchdb][:host]}:#{node[:couchdb][:port]}/#{node[:couchdb][:database]}/"
  ignore_failure true
end

# Generate new keys unless they have already been stored in settings.yml
if File.exists? "/vagrant/config/settings.yml"
  settings = YAML.load_file("/vagrant/config/settings.yml")["defaults"]
  node.set_unless['app']['key'] = settings["rest_auth_site_key"]
  node.set_unless['app']['secret'] = settings["session_secret"]
else
  # create new settings.yml
  node.set_unless['app']['key'] = SecureRandom.hex(30)
  node.set_unless['app']['secret'] = SecureRandom.hex(30)
  template "/vagrant/config/settings.yml" do
    source 'settings.yml.erb'
    owner 'root'
    group 'root'
    mode 0644
  end
end

# Run bundle command
bash "run bundle install in app directory" do
  cwd "/vagrant"
  code "bundle install"
end

# Optionally seed the database with sources, groups and sample articles
template "/vagrant/db/seeds/sources.seeds.erb" do
  source 'sources.seeds.erb'
  owner 'root'
  group 'root'
  mode 0644
end

# Create default databases and run migrations
bash "rake db:setup RAILS_ENV=#{node[:rails][:environment]}" do
  cwd "/vagrant"
  code "rake db:setup RAILS_ENV=#{node[:rails][:environment]}"
end

# Generate new Procfile
template "/vagrant/Procfile" do
  source 'Procfile.erb'
  owner 'root'
  group 'root'
  mode 0644
end

execute "disable-default-site" do
  command "sudo a2dissite default"
  notifies :reload, resources(:service => "apache2"), :delayed
end

web_app "alm" do
  docroot "/vagrant/public"
  template "alm.conf.erb"
  notifies :reload, resources(:service => "apache2"), :delayed
end