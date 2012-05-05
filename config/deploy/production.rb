require "rvm/capistrano"                  # Load RVM's capistrano plugin.
set :rvm_type, :system
set :rvm_ruby_string, '1.9.2-p320'        # Or whatever env you want it to run in.

require "bundler/capistrano"

set :application, "lincomp"

set :scm, :git
set :repository, "git://github.com/psy-q/stizun.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :keep_releases, 2

set :use_sudo, false
set :deploy_to, "/home/lincomp/production"


set :db_config, "/home/lincomp/database_prod.yml"
set :stizun_config, "/home/lincomp/stizun.yml"
set :email_config, "/home/lincomp/email.yml"
set :custom_directory, "/home/lincomp/custom"

role :web, "lincomp@www.lincomp.ch"                          # Your HTTP server, Apache/etc
role :app, "lincomp@www.lincomp.ch"                          # This may be the same as your `Web` server
role :db,  "lincomp@www.lincomp.ch", :primary => true # This is where Rails migrations will run

task :link_config do
  on_rollback { run "rm #{release_path}/config/database.yml" }
  if File.exist?("rm #{release_path}/config/database.yml")
    run "rm #{release_path}/config/database.yml"
  end
  run "ln -s #{db_config} #{release_path}/config/database.yml"
  run "rm #{release_path}/config/stizun.yml"
  run "ln -s #{stizun_config} #{release_path}/config/stizun.yml"
  run "rm #{release_path}/config/email.yml"
  run "ln -s #{email_config} #{release_path}/config/email.yml"

  run "sed -i 's,config.action_mailer.perform_deliveries = false,config.action_mailer.perform_deliveries = true,' #{release_path}/config/environments/production.rb"
end

task :link_files do
    run "ln -s #{deploy_to}/#{shared_dir}/tmp/downloads #{release_path}/tmp/downloads"
    run "ln -s #{deploy_to}/#{shared_dir}/uploads #{release_path}/public/uploads"
end

task :retrieve_db_config do
  # DB credentials needed by mysqldump etc.
  get(db_config, "/tmp/stizun_db_config.yml")
  dbconf = YAML::load_file("/tmp/stizun_db_config.yml")["production"]
  set :sql_database, dbconf['database']
  set :sql_username, dbconf['username']
  set :sql_password, dbconf['password']
end


task :migrate_database do
  # Produce a string like 2010-07-15T09-16-35+02-00
  date_string = DateTime.now.to_s.gsub(":","-")
  dump_dir = "#{deploy_to}/#{shared_dir}/db_backups"
  dump_path =  "#{dump_dir}/#{sql_database}-#{date_string}.sql"
  run "mkdir -p #{dump_dir}"
  # If mysqldump fails for any reason, Capistrano will stop here
  # because run catches the exit code of mysqldump
  run "mysqldump --user=#{sql_username} --password=#{sql_password} -r #{dump_path} #{sql_database}"
  run "bzip2 #{dump_path}"

  # Migration here 
  # deploy.migrate should work, but is buggy and is run in the _previous_ release's
  # directory, thus never runs anything? Strange.
  #deploy.migrate
  run "cd #{release_path} && RAILS_ENV='production'  bundle exec rake db:migrate"
end


task :configure_sphinx do
  run "cd #{release_path} && RAILS_ENV=production bundle exec rake ts:conf && RAILS_ENV=production bundle exec rake ts:reindex"
end

task :start_sphinx do
  run "cd #{release_path} && RAILS_ENV=production bundle exec rake ts:start"
end

task :stop_sphinx do
  run "cd #{release_path} && RAILS_ENV=production bundle exec rake ts:stop"
end

task :overwrite_custom do
  run "cd #{release_path} && rm -rf #{release_path}/custom"
  run "ln -s #{custom_directory} #{release_path}/custom"
end


namespace :deploy do
   task :restart, :roles => :app, :except => { :no_release => true } do
     #run "cd #{release_path} && RAILS_ENV='production' bundle exec rake db:migrate"
     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
   end

end

before "deploy:assets:precompile", :link_config
after "deploy:restart", "stop_sphinx"
after "link_config", "link_files"
before "migrate_database", "retrieve_db_config"
before "configure_sphinx", "migrate_database"
after "link_config", "configure_sphinx"
after "link_config", "overwrite_custom"
after "deploy:restart", "start_sphinx"
after "deploy", "deploy:cleanup"
