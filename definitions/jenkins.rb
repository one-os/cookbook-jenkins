# encoding: utf-8

define :add_jenkins_user do
  user node[:jenkins][:server][:user] do
    home node[:jenkins][:server][:home]
  end

  directory node[:jenkins][:server][:home] do
    recursive true
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end
end

define :copy_jenkins_config_files do
  %w{
  config.xml
  hudson.model.UpdateCenter.xml
  hudson.plugins.git.GitSCM.xml
  hudson.plugins.git.GitTool.xml
  hudson.plugins.gradle.Gradle.xml
  hudson.tasks.Mailer.xml
  hudson.tasks.Maven.xml }.each do |jenkins_config_file|

    template File.join(node[:jenkins][:server][:home], jenkins_config_file) do
      source "jenkins/config/#{jenkins_config_file}.erb"
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      mode 0644

      variables(
          authorization_strategy: 'unsecured',
          #authorization_strategy: node.jenkins.authorization_strategy,
          host_name:              node[:fqdn]
      )
    end
  end
end

define :setup_ssh do
  directory "#{node[:jenkins][:server][:home]}/.ssh" do
    mode 0700
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end

  file "#{node[:jenkins][:server][:home]}/.ssh/id_rsa" do
    user node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
    mode "0600"
    content node[:jenkins][:server][:private_key]
    not_if { File.exists?("#{node[:jenkins][:server][:home]}/.ssh/id_rsa") }
  end

  file "#{node[:jenkins][:server][:home]}/.ssh/id_rsa.pub" do
    user node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
    mode "0600"
    content node[:jenkins][:server][:public_key]
    not_if { File.exists?("#{node[:jenkins][:server][:home]}/.ssh/id_rsa.pub") }
  end

end

define :download_jenkins_plugins do
  directory "#{node[:jenkins][:server][:home]}/plugins" do
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
    only_if { node[:jenkins][:server][:plugins].size > 0 }
  end

  node[:jenkins][:server][:plugins].each do |plugin_name|
    remote_file "#{node[:jenkins][:server][:home]}/plugins/#{plugin_name}.jpi" do
      source "#{node[:jenkins][:mirror]}/plugins/#{plugin_name}/latest/#{plugin_name}.hpi"
      backup false
      owner node[:jenkins][:server][:user]
      group node[:jenkins][:server][:group]
      action :create
    end
  end

  log "downloaded Jenkins plugins" do
    notifies :start, "service[jenkins]", :immediately
  end
end

define :setup_jenkins_daemon do
  package "daemon" do
    action :install
  end

  template "/etc/default/jenkins" do
    mode 0644
  end

  template "/etc/init.d/jenkins" do
    source 'start-jenkins-daemon.erb'
    owner "root"
    group "root"
    mode 0755
  end

  # ln -s /etc/init.d/jenkins /etc/rc2.d/S92jenkins
  link "/etc/rc2.d/S92jenkins" do
    to "/etc/init.d/jenkins"
  end

  # ln -s /etc/init.d/jenkins /etc/rc0.d/K05jenkins
  link "/etc/rc0.d/K05jenkins" do
    to "/etc/init.d/jenkins"
  end
end

define :setup_http_proxy do
  case node[:jenkins][:http_proxy][:variant]
  when "nginx"
    include_recipe "jenkins::proxy_nginx"
  when "apache2"
    include_recipe "jenkins::proxy_apache2"
  end

  if node.jenkins.iptables_allow == "enable"
    include_recipe "iptables"
    iptables_rule "port_jenkins" do
      if node[:jenkins][:iptables_allow] == "enable"
        enable true
      else
        enable false
      end
    end
  end
end

define :store_jenkins_ssh_pubkey do
  ruby_block "store jenkins ssh pubkey" do
    block do
      node.set[:jenkins][:server][:pubkey] = File.open("#{ssh_key}.pub") { |f| f.gets }
    end
  end
end

define :restart_if_any_plugin_was_updated do
  log "plugins updated, restarting jenkins" do
    def plugin_updated_after?(htime)
      Dir["#{node[:jenkins][:server][:home]}/plugins/*.hpi"].select { |file|
        File.mtime(file) > htime
      }.size > 0
    end

    #ugh :restart does not work, need to sleep after stop.
    notifies :stop, "service[jenkins]", :immediately
    notifies :create, "ruby_block[until Jenkins shut down]", :immediately
    notifies :start, "service[jenkins]", :immediately
    notifies :create, "ruby_block[block_until_operational]", :immediately
    only_if { File.exists?(node.jenkins.server.pid_file) && plugin_updated_after?(File.mtime(node.jenkins.server.pid_file)) }
  end
end

define :block_until_operational do
  ruby_block "block_until_operational" do
    block do
      until IO.popen("netstat -lnt").entries.select { |entry|
          entry.split[3] =~ /:#{node[:jenkins][:server][:port]}$/
        }.size == 1
        Chef::Log.debug "service[jenkins] not listening on port #{node.jenkins.server.port}"
        sleep 1
      end

      loop do
        url = URI.parse("http://localhost:#{node['jenkins']['server']['port']}/job/test/config.xml")
        response = Chef::REST::RESTRequest.new(:GET, url, nil).call
        break if response.kind_of?(Net::HTTPSuccess) or \
                 response.kind_of?(Net::HTTPNotFound) or \
                 response.kind_of?(Net::HTTPForbidden)
        Chef::Log.debug "service[jenkins] not responding OK to GET / #{response.inspect}"
        sleep 1
      end
    end
    action :nothing
  end
end
