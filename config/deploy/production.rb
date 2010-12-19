set :application, "lincomp"

set :scm, :git
set :repository, "git://github.com/psy-q/stizun.git"
set :branch, "master"
set :deploy_via, :remote_cache


set :use_sudo, false
set :deploy_to, "/home/lincomp/production"


set :db_config, "/home/lincomp/database_prod.yml"


role :web, "lincomp@www.lincomp.org"                          # Your HTTP server, Apache/etc
role :app, "lincomp@www.lincomp.org"                          # This may be the same as your `Web` server
role :db,  "lincomp@www.lincomp.org", :primary => true # This is where Rails migrations will run

task :link_config do
  on_rollback { run "rm #{release_path}/config/database.yml" }
  run "rm #{release_path}/config/database.yml"
  run "ln -s #{db_config} #{release_path}/config/database.yml"
#  run "rm -r #{release_path}/test"
#  run "ln -s #{release_path}/public #{release_path}/test"
end

task :install_gems do
  run "cd #{release_path} && RAILS_ENV=production bundle install --deployment --without cucumber development"
end

namespace :deploy do
   task :restart, :roles => :app, :except => { :no_release => true } do
     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
   end

   task :after_deploy do
     cleanup
   end 
end




after "deploy:symlink", :link_config
after "link_config", "install_gems"
