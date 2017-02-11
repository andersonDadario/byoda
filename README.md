## Getting started

This is a proof of concept - not a production ready application - to complement my blog post:  
[https://dadario.com.br/building-data-breach-resistant-applications-bring-your-own-database/](https://dadario.com.br/building-data-breach-resistant-applications-bring-your-own-database/)

1. Requirements
    - Ruby 2.3+
    - Docker
    - cURL
2. Set up MySQL Databases
    - One for BYODA (this application)
    - One for User A
    - One for User B
3. For each user
    - Create User
    - Let BYODA create tables on the user specified MySQL
    - Create a Task
    - List Tasks

### Getting your hands dirty

Initialize all 3 MySQL containers:

```sh
# Create MySQL containers
docker run --name mysql-poc -d -e MYSQL_ROOT_HOST=172.17.0.1 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql/mysql-server;
docker run --name mysql-poc2 -d -e MYSQL_ROOT_HOST=172.17.0.1 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql/mysql-server;
docker run --name mysql-poc3 -d -e MYSQL_ROOT_HOST=172.17.0.1 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql/mysql-server;

# Await for them to initialize
sleep 90;

# Create Databases
docker exec -it --user=root mysql-poc mysql -u root -D mysql -e "CREATE DATABASE byoda;";
docker exec -it --user=root mysql-poc2 mysql -u root -D mysql -e "CREATE DATABASE byoda2;";
docker exec -it --user=root mysql-poc3 mysql -u root -D mysql -e "CREATE DATABASE byoda3;";

# Retrieve IP Addresses
export MYSQL_POC_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql-poc);
export MYSQL_POC_IP2=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql-poc2);
export MYSQL_POC_IP3=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mysql-poc3);
```

Testing the PoC:

```sh
# Solve dependencies for 'byoda.rb'
bundle install

# Start Application
# Requires access to "MYSQL_POC_IP" env variable
ruby byoda.rb &

# Create BYODA "User table" on "mysql-poc" container
# Used to store users' DMS credentials
curl http://localhost:8080/setup --data ""
# {
#   "success": true
# }

# Create "User A"
text=''
text="${text}email=a@a.com"
text="${text}&password=letmein"
text="${text}&dms_adapter=mysql2"
text="${text}&dms_host=$MYSQL_POC_IP2"
text="${text}&dms_username=root"
text="${text}&dms_password="
text="${text}&dms_database=byoda2"
curl http://localhost:8080/users --data $text
# {
#   "success": true
# }

# Setup "User A" DMS
# This operation creates the "tasks" table
curl http://localhost:8080/users/1/setup --data ""
# {
#   "success": true
# }

# Create task for "User A"
curl http://localhost:8080/users/1/tasks --data "task[title]=MyTitle&task[description]=Something"
# {
#   "success": true
# }

# Load tasks for "User A"
curl http://localhost:8080/users/1/tasks
# [
#   {
#     "id": 1,
#     "title": "MyTitle",
#     "description": "Something"
#   }
# ]

# Create "User B"
text=''
text="${text}email=b@b.com"
text="${text}&password=letmein"
text="${text}&dms_adapter=mysql2"
text="${text}&dms_host=$MYSQL_POC_IP3"
text="${text}&dms_username=root"
text="${text}&dms_password="
text="${text}&dms_database=byoda3"
curl http://localhost:8080/users --data $text
# {
#   "success": true
# }

# Setup "User B" DMS
# This operation creates the "tasks" table
curl http://localhost:8080/users/2/setup --data ""
# {
#   "success": true
# }

# Create task for "User B"
curl http://localhost:8080/users/2/tasks --data "task[title]=MyTitle2&task[description]=Something2"
# {
#   "success": true
# }

# Load tasks for "User B"
curl http://localhost:8080/users/2/tasks
# [
#   {
#     "id": 1,
#     "title": "MyTitle2",
#     "description": "Something2"
#   }
# ]

# List all users
curl http://localhost:8080/users
# [
#   {
#     "id": 1,
#     "email": "a@a.com",
#     "password": "letmein",
#     "dms_adapter": "mysql2",
#     "dms_host": "172.17.0.3",
#     "dms_username": "root",
#     "dms_password": "",
#     "dms_database": "byoda2"
#   },
#   {
#     "id": 2,
#     "email": "b@b.com",
#     "password": "letmein",
#     "dms_adapter": "mysql2",
#     "dms_host": "172.17.0.4",
#     "dms_username": "root",
#     "dms_password": "",
#     "dms_database": "byoda3"
#   }
# ]

```

### Command to access MySQL console:

```sh
container_name=mysql-poc
docker exec -it --user root $container_name mysql
```

### References that helped me make this PoC:

- http://www.ostinelli.net/setting-multiple-databases-rails-definitive-guide/
- https://gist.github.com/robhurring/342648/ac8aea19f7de99fcede68e79b92e8e84e50cacbc
- http://stackoverflow.com/questions/180349/how-can-i-dynamically-change-the-active-record-database-for-all-models-in-ruby-o