# encoding: utf-8

define :create_jenkins_job do

  job_name   = params[:name]

  job_config = File.join(node[:jenkins][:server][:home], "#{ job_name }-config.xml")

  jenkins_job job_name do
    action :nothing
    config job_config
    url    "http://localhost:#{node['jenkins']['server']['port']}"
  end

  directory "#{node[:jenkins][:server][:home]}/jobs" do
    user  node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end

  directory "#{node[:jenkins][:server][:home]}/jobs/#{job_name}" do
    user  node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end

  directory "#{node[:jenkins][:server][:home]}/jobs/#{job_name}/workspace" do
    user  node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end

  git "#{node[:jenkins][:server][:home]}/jobs/#{job_name}/workspace" do
    repository params[:git_url]
    reference  params[:git_branch]
    depth      5

    user  node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
    action     :sync
  end

  template job_config do
    source params[:template]
    variables git_url: params[:git_url], git_branch: params[:git_branch]
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
    mode 0644

    notifies :update, resources(:jenkins_job => job_name), :delayed
    notifies :build,  resources(:jenkins_job => job_name), :delayed
  end

end
