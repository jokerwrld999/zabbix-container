#!/bin/bash

# **** Messages Variables
success_message="OK!"

# **** Get Database Variables
while :
do
    read -p "Choose A Installation Type Of Zabbix: server Or proxy [server]: " setup_type
    setup_type=${setup_type:-server}
    if [[ $setup_type == "server" ]]
    then
        read -p "Enter Database User [zabbix]: " POSTGRES_USER
        POSTGRES_USER=${POSTGRES_USER:-zabbix}
        echo $POSTGRES_USER
        read -p "Enter Database Password [zabbix]: " POSTGRES_PASSWORD
        POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-zabbix}
        read -p "Enter Database Name [zabbixDB]: " POSTGRES_DB
        POSTGRES_DB=${POSTGRES_DB:-zabbixDB}
        break
    elif [[ $setup_type == "proxy" ]]
    then
        echo $success_message
        break
    else
        echo "Please Enter A Valid Installation Type Of Zabbix"  
    fi
done

# **** Set Database Variables
sudo sed -i "s/POSTGRES_USER=.*/POSTGRES_USER=$POSTGRES_USER/" ./variables.env
sudo sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" ./variables.env
sudo sed -i "s/POSTGRES_DB=.*/POSTGRES_DB=$POSTGRES_DB/" ./variables.env

# **** Cross-Distro Packages Installation
check_pkg_manager() {
    if [[ -x "$(command -v apt)" ]]
    then 
        sudo apt install -y $packagesNeeded
    elif [[ -x "$(command -v dnf)" ]]
    then 
        sudo dnf install -y $packagesNeeded
    else 
        echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: $packagesNeeded">&2; 
    fi
}

# **** Docker Anf UFW Setup
if [[ -x "$(command -v apt)" ]]
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
    echo $success_message
fi

# **** Docker Setup
echo -ne "
-------------------------------------------------------------------------
                     Checking For Docker Package....
-------------------------------------------------------------------------
"
if [[ -x "$(command -v docker)" ]]
then
    echo $success_message
else
    echo -ne "
    -------------------------------------------------------------------------
                     Installing Docker Package....
    -------------------------------------------------------------------------
    "
    # *** Curl Install
    if [[ -x "$(command -v curl)" ]]
    then
        echo $success_message
    else
        packagesNeeded='curl'
        check_pkg_manager
    fi
    curl -fsSL https://get.docker.com -o get-docker.sh
    # *** Docker Setup
    sudo sh ./get-docker.sh
    if [[ whoami !== root ]]
    then
        sudo usermod -aG docker $USER
    else
        echo $success_message
    fi
fi

# **** Docker-Compose Setup
echo -ne "
-------------------------------------------------------------------------
                     Checking For Docker-Compose Package....
-------------------------------------------------------------------------
"
if [[ -x "$(command -v docker-compose)" ]]
then
    echo $success_message
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
run=${1:-"up -d"}
compose_file="docker-compose-$setup_type.yaml"
docker-compose -f ./$compose_file $run

# *** Container Status Check
container_status=$(docker inspect web-nginx-pgsql | grep "Status" | tail -n1 | awk -F ":" '{print $2}' | sed 's/,.*//')
while [[ echo $container_name == "starting" ]]
do
    sleep 3
    echo $container_status
done
if [[ echo $container_status == "healthy" ]]
then
    echo -ne "
    -------------------------------------------------------------------------
                    Setup Was Done Correctly! You Good To Go!
                    Database Password: $POSTGRES_PASSWORD
                    Service Running On Port: 80 And 443
    -------------------------------------------------------------------------
    "
else
    echo -ne "
    -------------------------------------------------------------------------
                    Something Went Wrong!
    -------------------------------------------------------------------------
    "
fi