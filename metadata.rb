name              "alm"
maintainer        "Martin Fenner"
maintainer_email  "mfenner@plos.org"
license           "Apache 2.0"
description       "Configures ALM server"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "1.0.1"
depends           "apt"
depends           "build-essential"
depends           "git"
depends           "ruby_build"
depends           "rbenv"
depends           "passenger_apache2"
depends           "mysql"
depends           "couchdb"
depends           "phantomjs"

%w{ ubuntu centos }.each do |os|
  supports os
end