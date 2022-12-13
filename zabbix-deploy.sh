#!/bin/bash

# >>>>> Get Database Variables
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
        echo "OK!"
        break
    else
        echo "Please Enter A Valid Installation Type Of Zabbix"  
    fi
done



# >>>>> Get Container Info
compose_file="docker-compose-$setup_type.yaml"
echo $compose_file
host_port=$(cat $compose_file | grep -A4 -i ports | head -n2 | awk -e '{print $2}' | awk -F ':' '{print $1}')


# >>>>> Get Host Info
container_status=$(docker inspect $container_name | grep Running | awk -F ":" '{print $2}' | sed 's/,.*//')

check_pkg_manager() {
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
    packagesNeeded='docker-compose'
    check_pkg_manager
fi

echo -ne "
-------------------------------------------------------------------------
                    Starting $container_name Container....
-------------------------------------------------------------------------
"
#docker-compose -f ./$compose_file up -d

docker ps

