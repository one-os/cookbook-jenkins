#
# Cookbook Name:: jenkins
# Recipe:: default
#
# Author:: Andreas Simon <a.simon@one-os.de>
#
# Copyright 2012, Andreas Simon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

service "jenkins" do
  supports [ :stop, :start, :restart, :status ]
  status_command "test -f #{node.jenkins.server.pid_file}"
  action :stop
end

add_jenkins_user()
setup_ssh()
copy_jenkins_config_files()


directory "/usr/share/jenkins" do
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
end

directory "/var/lib/jenkins" do
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
end

%w{ /var/cache/jenkins /var/log/jenkins /var/run/jenkins }.each do |dir|
  directory dir do
    owner "root"
    group "root"
  end
end

setup_jenkins_daemon()
download_jenkins_plugins()

template "/etc/logrotate.d/jenkins" do
  source 'logrotate-jenkins.erb'
  owner "root"
  group "root"
  mode 0644
end

remote_file "/usr/share/jenkins/jenkins.war" do
  source "#{node[:jenkins][:mirror]}/war/latest/jenkins.war"
  backup false
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  mode 0644
  action :nothing
end


#"jenkins stop" may (likely) exit before the process is actually dead
#so we sleep until nothing is listening on jenkins.server.port (according to netstat)
ruby_block "until Jenkins shut down" do
  block do
    10.times do
      if IO.popen("netstat -lnt").entries.select { |entry|
          entry.split[3] =~ /:#{node[:jenkins][:server][:port]}$/
        }.size == 0
        break
      end
      Chef::Log.debug("service[jenkins] still listening (port #{node[:jenkins][:server][:port]})")
      sleep 1
    end
  end
  action :nothing
end

block_until_operational()

log "jenkins: install and start" do
  notifies :create, "remote_file[/usr/share/jenkins/jenkins.war]", :immediately
  notifies :start, "service[jenkins]", :immediately
  notifies :create, "ruby_block[block_until_operational]", :immediately
  not_if { File.exists? "/usr/share/jenkins/jenkins.war" }
end

restart_if_any_plugin_was_updated()
setup_http_proxy()
