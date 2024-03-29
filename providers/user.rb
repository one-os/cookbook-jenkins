#
# Cookbook Name:: jenkins
# Provider:: user
#
# Author:: Andreas Simon <a.simon@one-os.de>
#
# Copyright:: 2012, Andreas Simon
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

def jbcrypt(secret)
  jbcrypt_lib_path = ::File.expand_path("../../files/default/jbcrypt-0.3.1.jar", __FILE__)
  `#{node[:java][:java_home]}/bin/java -jar #{jbcrypt_lib_path} #{secret}`.delete("\n")
end

def action_create
  directory "#{node[:jenkins][:server][:home]}/users" do
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:user]
    mode 0755
  end

  directory "#{node[:jenkins][:server][:home]}/users/#{new_resource.name}" do
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:user]
    mode 0755
  end

  template "#{node[:jenkins][:server][:home]}/users/#{new_resource.name}/config.xml" do
    cookbook 'jenkins'
    source "jenkins/config/user/config.xml.erb"
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:user]
    mode 0644
    variables(
      full_name: new_resource.full_name,
      password_hash: jbcrypt(new_resource.password),
      email: new_resource.email
    )
  end
end
