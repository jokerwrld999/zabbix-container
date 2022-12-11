#!/bin/bash

# >>>>> Get Container Info
compose_file="docker-compose.yaml"
container_name=$(cat $compose_file | grep container_name | awk -e '{print $2}')
host_port=$(cat $compose_file | grep -A4 -i ports | head -n2 | awk -e '{print $2}' | awk -F ':' '{print $1}')
container_volumes=$(cat $compose_file | grep -A4 -i volumes | tail -n1 | awk -F ':' '{print $1}')

# >>>>> Get Host Info
host_volume=$(docker volume ls | grep $container_volumes | awk -F ' ' '{print $2}' )
mountpoint_on_host=$(docker inspect $host_volume | grep Mountpoint | awk -F ':' '{print $2}' | cut -d '"' -f2)
init_password_location="$mountpoint_on_host/secrets/initialAdminPassword"
init_password=$(sudo cat $init_password_location 2>/dev/null)
container_status=$(docker inspect $container_name | grep Running | awk -F ":" '{print $2}' | sed 's/,.*//')

if [ -x "$(command -v apt)" ]
then
    echo -ne "
    -------------------------------------------------------------------------
            Setup The Docker and UFW Security On Debian Based System....
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
    ufw-docker allow $container_name
else
    echo "OK!"
fi

echo -ne "
-------------------------------------------------------------------------
                     Checking For Docker Package....
-------------------------------------------------------------------------
"
if [ -x "$(command -v docker)" ]
then
    echo "OK!"
else
    echo -ne "
    -------------------------------------------------------------------------
                     Installing Docker Package....
    -------------------------------------------------------------------------
    "
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    sudo usermod -aG docker $USER
fi

echo -ne "
-------------------------------------------------------------------------
                     Checking For Docker-Compose Package....
-------------------------------------------------------------------------
"
if [ -x "$(command -v docker-compose)" ]
then
    echo "OK!"
else
    echo -ne "
    -------------------------------------------------------------------------
                     Installing Docker-Compose Package....
    -------------------------------------------------------------------------
    "
    $packagesNeeded='docker-compose'
    check_pkg_manager
fi

echo -ne "
-------------------------------------------------------------------------
                    Starting $container_name Container....
-------------------------------------------------------------------------
"
docker-compose -f ./$compose_file up -d

if $(sudo test -f "$init_password_location")
then
    echo -ne "
    -------------------------------------------------------------------------
                    Setup Was Done Correctly! You Good To Go!
                    Initial Password: $init_password
                    Service Running On Port: $host_port
    -------------------------------------------------------------------------
    "
elif [ $container_status = "true" ]
then
    echo -ne "
    -------------------------------------------------------------------------
                    Service Running On Port: $host_port
    -------------------------------------------------------------------------
    "
else
    echo -ne "
    -------------------------------------------------------------------------
                    Something Went Wrong!
    -------------------------------------------------------------------------
    "
fi

check_pkg_manager(){
    if [ -x "$(command -v apt)" ]
    then 
        sudo apt install -y $packagesNeeded
    elif [ -x "$(command -v dnf)" ]
    then 
        sudo dnf install $packagesNeeded
    else 
        echo "FAILED TO INSTALL PACKAGE: Package manager not found. You must manually install: $packagesNeeded">&2; 
    fi
}