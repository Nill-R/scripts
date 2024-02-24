#!/usr/bin/env bash

# Script create by OpenAI ChatGPT and don't check for work currently

# Set the directory for storing generated data
deploy_dir="/root/wp_auto_deploy"

# Ensure the deploy directory exists
mkdir -p "$deploy_dir"

# Loop through each domain in the file
while IFS= read -r domain || [[ -n "$domain" ]]; do
    # Generate a random password for the database
    db_password=$(pwgen -1 12)
    
    # Set database user and database name
    db_user="${domain}_user"
    db_name="${domain}_db"
    
    # Write database info to a file
    echo "# Database info for $domain" >> "$deploy_dir/database_info.txt"
    echo "Domain: $domain" >> "$deploy_dir/database_info.txt"
    echo "DB User: $db_user" >> "$deploy_dir/database_info.txt"
    echo "DB Name: $db_name" >> "$deploy_dir/database_info.txt"
    echo "DB Password: $db_password" >> "$deploy_dir/database_info.txt"
    echo "" >> "$deploy_dir/database_info.txt"

    # Create MySQL user and database, grant privileges
    mysql -e "CREATE DATABASE IF NOT EXISTS $db_name; \
              CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password'; \
              GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
    
    # Set the directory for the website
    site_dir="/srv/web/$domain"
    
    # Create directory for the website
    mkdir -p "$site_dir"
    
    # Change to the website directory
    cd "$site_dir" || exit
    
    # Download WordPress
    wp core download --path="$site_dir"
    
    # Create WordPress configuration file
    wp config create --dbname="$db_name" --dbuser="$db_user" --dbpass="$db_password" --prompt=0
    
    # Create the database tables
    wp db create
    
    # Install WordPress
    wp core install --url="$domain" --title="$domain" --admin_user=admin --admin_password=admin_password --admin_email=support@"$domain"
    
    # Output message indicating completion
    echo "WordPress deployed for $domain"
done < domains.txt
