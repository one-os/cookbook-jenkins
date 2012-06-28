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

def action_create
  directory "#{node[:jenkins][:server][:home]}/users" do
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:user]
    mode 0755
  end

  directory "#{node[:jenkins][:server][:home]}/users/a.simon@one-os.de" do
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:user]
    mode 0755
  end

  template "#{node[:jenkins][:server][:home]}/users/a.simon@one-os.de/config.xml" do
    cookbook 'jenkins'
    source "jenkins/config/user/config.xml.erb"
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:user]
    mode 0644
  end
end
