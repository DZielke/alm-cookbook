if node['platform'] == "ubuntu"
  # Install required packages
  %w{ruby1.9.3 libxslt-dev libxml2-dev curl}.each do |pkg|
    package pkg do
      action :install
    end
  end
  gem_package "bundler" do
    gem_binary "/usr/bin/gem"
  end
end

# Install required gems via bundler
script "bundle" do
  interpreter "bash"
  cwd "/vagrant"
  code "bundle install"
end

# Create new settings.yml
require 'securerandom'
node.set_unless['alm']['key'] = SecureRandom.hex(30)
node.set_unless['alm']['secret'] = SecureRandom.hex(30)
template "/vagrant/config/settings.yml" do
  source 'settings.yml.erb'
  owner 'root'
  group 'root'
  mode 0644
end

# Create new database.yml
template "/vagrant/config/database.yml" do
  source 'database.yml.erb'
  owner 'root'
  group 'root'
  mode 0644
end

# Optionally seed the database with sources, groups and sample articles
template "/vagrant/db/seeds/sources.seeds.erb" do
  source 'sources.seeds.erb'
  owner 'root'
  group 'root'
  mode 0644
end

# Create default databases and run migrations
script "rake db:setup RAILS_ENV=#{node[:alm][:environment]}" do
  interpreter "bash"
  cwd "/vagrant"
  code "rake db:setup RAILS_ENV=#{node[:alm][:environment]}"
end

# Create default CouchDB database
script "create CouchDB database #{node[:alm][:name]}" do
  interpreter "bash"
  code "curl -X DELETE http://#{node[:couchdb][:host]}:#{node[:couchdb][:port]}/#{node[:alm][:name]}/"
  code "curl -X PUT http://#{node[:couchdb][:host]}:#{node[:couchdb][:port]}/#{node[:alm][:name]}/"
  ignore_failure true
end

# Generate new Procfile
template "/vagrant/Procfile" do
  source 'Procfile.erb'
  owner 'root'
  group 'root'
  mode 0644
end

case node['platform']
when "ubuntu"
  include_recipe "passenger_apache2::mod_rails"
  
  execute "disable-default-site" do
    command "sudo a2dissite default"
  end

  web_app "alm" do
    template "alm.conf.erb"
    notifies :reload, resources(:service => "apache2"), :delayed
  end
when "centos"
  template "/etc/httpd/conf.d/alm.conf" do
    source 'alm.conf.erb'
    owner 'root'
    group 'root'
    mode 0644
  end
  
  script "start httpd" do
    interpreter "bash"
    code "sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT"
    code "sudo service iptables save"
    code "sudo /etc/init.d/iptables restart"
    code "sudo chkconfig --levels 235 httpd on"
    code "sudo /sbin/service httpd start"
  end
end