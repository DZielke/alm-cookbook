# Install required packages
%w{ruby1.9.3 curl}.each do |pkg|
  package pkg do
    action :install
  end
end
gem_package "bundler" do
  gem_binary "/usr/bin/gem"
end

require 'securerandom'
# Create new settings.yml unless it exists already
# Set these passwords in config.json to keep them persistent
unless File.exists?("/var/www/alm/shared/config/settings.yml")
  node.set['alm']['key'] = SecureRandom.hex(30) unless node['alm']['key']
  node.set['alm']['secret'] = SecureRandom.hex(30) unless node['alm']['secret']
  node.set['alm']['api_key'] = SecureRandom.hex(30) unless node['alm']['api_key']
else
  settings = YAML::load(IO.read("/var/www/alm/shared/config/settings.yml"))
  rest_auth_site_key = settings["#{node[:alm][:environment]}"]["rest_auth_site_key"]
  secret_token = settings["#{node[:alm][:environment]}"]["secret_token"]
  api_key = settings["#{node[:alm][:environment]}"]["api_key"]

  node.set_unless['alm']['key'] = rest_auth_site_key
  node.set_unless['alm']['secret'] = secret_token
  node.set_unless['alm']['api_key'] = api_key
end

template "/var/www/alm/shared/config/settings.yml" do
  source 'settings.yml.erb'
  owner 'root'
  group 'root'
  mode 0644
end

# Create new database.yml unless it exists already
# Set these passwords in config.json to keep them persistent
unless File.exists?("/var/www/alm/shared/config/database.yml")
  node.set_unless['mysql']['server_root_password'] = SecureRandom.hex(8)
  node.set_unless['mysql']['server_repl_password'] = SecureRandom.hex(8)
  node.set_unless['mysql']['server_debian_password'] = SecureRandom.hex(8)
  database_exists = false
else
  database = YAML::load(IO.read("/var/www/alm/shared/config/database.yml"))
  server_root_password = database["#{node[:alm][:environment]}"]["password"]

  node.set_unless['mysql']['server_root_password'] = server_root_password
  node.set_unless['mysql']['server_repl_password'] = server_root_password
  node.set_unless['mysql']['server_debian_password'] = server_root_password
  database_exists = true
end

template "/var/www/alm/shared/config/database.yml" do
  source 'database.yml.erb'
  owner 'root'
  group 'root'
  mode 0644
end

include_recipe "mysql::server"

# # Add configuration settings to database seed files
# template "/var/www/alm/current/_custom_sources.rb" do
#   source '_custom_sources.rb.erb'
#   owner 'root'
#   group 'root'
#   mode 0644
# end

# # Install required gems via bundler
# script "bundle" do
#   interpreter "bash"
#   cwd "/vagrant"
#   code "bundle install"
# end

# # Create default databases if they don't exist yet and run migrations otherwise
# if database_exists
#   script "RAILS_ENV=#{node[:alm][:environment]} rake db:migrations" do
#     interpreter "bash"
#     cwd "/vagrant"
#     code "RAILS_ENV=#{node[:alm][:environment]} rake db:migrations"
#     code "RAILS_ENV=#{node[:alm][:environment]} rake db:seed"
#   end
# else
#   script "RAILS_ENV=#{node[:alm][:environment]} rake db:setup" do
#     interpreter "bash"
#     cwd "/vagrant"
#     if node[:alm][:seed_sample_articles]
#       code "RAILS_ENV=#{node[:alm][:environment]} rake db:setup ARTICLES='1'"
#     else
#       code "RAILS_ENV=#{node[:alm][:environment]} rake db:setup"
#     end
#   end
# end

# Create default CouchDB database
script "create CouchDB database #{node[:alm][:name]}" do
  interpreter "bash"
  code "curl -X PUT http://#{node[:alm][:host]}:#{node[:couch_db][:config][:httpd][:port]}/#{node[:alm][:name]}/"
  ignore_failure true
end

node.set_unless['passenger']['root_path'] = "/var/lib/gems/1.9.1/gems/passenger-#{node['passenger']['version']}"
node.set_unless['passenger']['module_path'] = "/var/lib/gems/1.9.1/gems/passenger-#{node['passenger']['version']}/ext/apache2/mod_passenger.so"
include_recipe "passenger_apache2::mod_rails"

execute "disable-default-site" do
  command "sudo a2dissite default"
end

web_app "alm" do
  template "alm.conf.erb"
  notifies :restart, resources(:service => "apache2"), :delayed
end