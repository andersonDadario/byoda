require 'mysql2'
require 'sinatra'
require 'active_record'
require 'json'

set :bind, '127.0.0.1'
set :port, '8080'

unless ENV["MYSQL_POC_IP"]
    p "MYSQL_POC_IP env variable not specified"
    p "Please read the 'README' file"
    p "Exiting..."
    return false
end

ActiveRecord::Base.configurations = {
  # Database to store users' DMS credentials
  'mysql' => {
    'adapter' => 'mysql2',
    'host' => ENV["MYSQL_POC_IP"],
    'username' => 'root',
    'password' => '',
    'database' => 'mysql'
  }
}

class User < ActiveRecord::Base
    ActiveRecord::Base.establish_connection(:mysql)
end

class Task < ActiveRecord::Base
    # Empty
end

  #
  # POST /setup
  # Create "users" table on BYODA's DMS
  #
  post '/setup' do
    begin
        # Create Users Table
        ActiveRecord::Base.establish_connection(:mysql)
        ActiveRecord::Migration.create_table :users do |t|
          t.string :email
          t.string :password
          t.string :dms_adapter
          t.string :dms_host
          t.string :dms_username
          t.string :dms_password
          t.string :dms_database
        end
        byoda_render({success: true})
    rescue => e
        return byoda_render({success: false, exception: e.message})
    end
  end

  #
  # GET /users
  # List all user records on BYODA's DMS
  #
  get '/users' do
    begin
        ActiveRecord::Base.establish_connection(:mysql)
        byoda_render(User.all.map{ |x| x.attributes })
    rescue => e
        byoda_render({success: false, exception: e.message})
    end
  end

  #
  # GET /users/:id/tasks
  # List all task records on User's DMS
  #
  get %r{/users/([\d]+)/tasks} do
    begin
        # Load user
        ActiveRecord::Base.establish_connection(:mysql)
        user_id = params[:captures].first.to_i
        user = User.find(user_id)

        # Establish connection to user's DMS
        Task.establish_connection(
            adapter: user.dms_adapter,
            host: user.dms_host,
            username: user.dms_username,
            password: user.dms_password,
            database: user.dms_database
        )

        # Load Tasks
        byoda_render(Task.all.map{ |x| x.attributes })
    rescue => e
        return byoda_render({success: false, exception: e.message})
    end
  end

  #
  # POST /users/:id/tasks
  # Create task record on User's DMS
  #
  post %r{/users/([\d]+)/tasks} do
    begin
        # Load user
        ActiveRecord::Base.establish_connection(:mysql)
        user_id = params[:captures].first.to_i
        user = User.find(user_id)

        # Establish connection to user's DMS
        Task.establish_connection(
            adapter: user.dms_adapter,
            host: user.dms_host,
            username: user.dms_username,
            password: user.dms_password,
            database: user.dms_database
        )

        # Create Task
        strong_parameters = {}
        strong_parameters[:title] = params[:task][:title]
        strong_parameters[:description] = params[:task][:description]
        p "Creating task for User #{user_id}"
        p "Strong Parameters: #{strong_parameters}"
        Task.create(strong_parameters)
        byoda_render({success: true})
    rescue => e
        return byoda_render({success: false, exception: e.message})
    end
  end

  #
  # POST /users
  # Create user record on BYODA's DMS
  #
  post '/users' do
    # Extremely dangerous to don't validate input like this
    # In production. Don't do this, validate input instead :)
    begin
        ActiveRecord::Base.establish_connection(:mysql)
        User.create(params)
        byoda_render({success: true})
    rescue => e
        return byoda_render({success: false, exception: e.message})
    end    
  end

  #
  # POST /users/:id/setup
  # Create "tasks" table on User's DMS
  #
  post %r{/users/([\d]+)/setup} do
    begin
        ActiveRecord::Base.establish_connection(:mysql)
        user_id = params[:captures].first.to_i
        user = User.find(user_id)

        ActiveRecord::Base.establish_connection(
            adapter: user.dms_adapter,
            host: user.dms_host,
            username: user.dms_username,
            password: user.dms_password,
            database: user.dms_database
        )
        
        ActiveRecord::Migration.create_table :tasks do |t|
          t.string :title
          t.string :description
        end

        byoda_render({success: true})
    rescue => e
        byoda_render({success: false, exception: e.message})
    end
  end

  #
  # GET /
  # List all routes
  #
  get '/' do
    byoda_render({
        routes: {
            "[POST] /setup" => {
                description: "Create users table",
                parameters: {}
            },
            "[GET] /users" => {
                description: "List all users"
            },
            "[GET] /users/<ID>/tasks" => {
                description: "List user <ID> tasks"
            },
            "[POST] /users" => {
                description: "Create a user <ID>",
                parameters: {
                    email: "[STRING] Email address",
                    password: "[STRING] User password",
                    dms_adapter: "[STRING] DMS adapter (only MySQL)",
                    dms_host: "[STRING] DMS host (e.g., 15.230.150.25)",
                    dms_username: "[STRING] DMS username (e.g., root)",
                    dms_password: "[STRING] DMS password (e.g., toor)",
                    dms_database: "[STRING] DMS database (e.g., byoda)"
                }
            },
            "[POST] /users/<ID>/setup" => {
                description: "Create tables on user <ID> DMS",
                parameters: {}
            },
            "[POST] /users/<ID>/tasks" => {
                description: "Create a task for user <ID>",
                parameters: {
                    task: {
                        title: "[STRING] title",
                        description: "[STRING] description",
                    }
                }
            }
        }
    })  
  end

  def byoda_render(obj)
    JSON.pretty_generate(obj)
  end
