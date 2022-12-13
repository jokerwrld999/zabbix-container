#!/bin/bash

# **** Messages Variables
success_message="OK!"

# **** Get Database Variables
while :
do
    read -p "Choose A Installation Type Of Zabbix: server Or proxy: " setup_type
    if [ $setup_type = "server" ]
    then
        read -p "Enter Database User" POSTGRES_USER
        read -p "Enter Database Password" POSTGRES_PASSWORD
        read -p "Enter Database Name" POSTGRES_DB
        break
    elif [ $setup_type = "proxy" ]
    then
        $success_message
        break
    else
        echo "Please Enter A Valid Installation Type Of Zabbix"  
    fi
done

# **** Set Database Variables
sudo sed -i "s/POSTGRES_USER=.*/POSTGRES_USER=$POSTGRES_USER/" ./variables.env
sudo sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" ./variables.env
sudo sed -i "s/POSTGRES_DB=.*/POSTGRES_DB=$POSTGRES_DB/" ./variables.env

# **** Get Host Info
container_status=$(docker inspect $container_name | grep Running | awk -F ":" '{print $2}' | sed 's/,.*//')

# **** Cross-Distro Packages Installation
check_pkg_manager() {
    if [ -x "$(command -v apt)" ]
    then 
        sudo apt install -y $packagesNeeded
    elif [ -x "$(command -v dnf)" ]
    then 
        sudo dnf install -y $packagesNeeded
    else 
        echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: $packagesNeeded">&2; 
    fi
}

# **** Docker Anf UFW Setup
if [ -x "$(command -v apt)" ]
then
    echo -ne "
    -------------------------------------------------------------------------
            Setup The Docker And UFW Security On Debian Based System....
    -------------------------------------------------------------------------
    "
    # *** Install And Enable UFW
    sudo apt install -y ufw
    sudo ufw enable
    # *** Download ufw-docker Script
    sudo wget -O /usr/local/bin/ufw-docker https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
    sudo chmod +x /usr/local/bin/ufw-docker
    # *** Modify UFW Rules
    ufw-docker install
    # *** Expose Ports Of The Container
    ufw-docker allow web-nginx-pgsql
else
    $success_message
fi

# **** Docker Setup
echo -ne "
-------------------------------------------------------------------------
                     Checking For Docker Package....
-------------------------------------------------------------------------
"
if [ -x "$(command -v docker)" ]
then
    $success_message
else
    echo -ne "
    -------------------------------------------------------------------------
                     Installing Docker Package....
    -------------------------------------------------------------------------
    "
    # *** Curl Install
    if [ -x "$(command -v curl)" ]
    then
        $success_message
    else
        packagesNeeded='curl'
        check_pkg_manager
    fi
    curl -fsSL https://get.docker.com -o get-docker.sh
    # *** Docker Setup
    sudo sh ./get-docker.sh
    if [ whoami !=root ]
    then
        sudo usermod -aG docker $USER
    else
        $success_message
    fi
fi

# **** Docker-Compose Setup
echo -ne "
-------------------------------------------------------------------------
                     Checking For Docker-Compose Package....
-------------------------------------------------------------------------
"
if [ -x "$(command -v docker-compose)" ]
then
    $success_message
else
    echo -ne "
    -------------------------------------------------------------------------
                     Installing Docker-Compose Package....
    -------------------------------------------------------------------------
    "
    # *** Docker Compose Setup
    packagesNeeded='docker-compose'
    check_pkg_manager
fi

# **** Docker-Compose Start
echo -ne "
-------------------------------------------------------------------------
                    Starting Zabbix Service....
-------------------------------------------------------------------------
"
$1="up -d"
compose_file="docker-compose-$setup_type.yaml"
docker-compose -f ./$compose_file $1
echo $1
docker ps

