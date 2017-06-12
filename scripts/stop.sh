#!/usr/bin/env bash

SVC_NAME=rabbit
NET_NAME=test

RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

force=$( if [ "${1:-ask}" == "force" ]; then echo 1; else echo 0; fi )

function prompt_to_proceed_yes () {
  ans=yes
  if [ "$force" == "0" ]; then
    ans="yes"
    while true; do
      echo -en "${CYAN}> $1 [Yn]: ${NC}"
      read -p "" yn
      case $yn in
        [Yy]* ) ans=yes; break;;
        [Nn]* ) ans=no; break;;
        * ) ans=yes; break;;
      esac
    done
  else
    echo -e "${CYAN}> $1 [Yn]: Y ${NC}"
  fi
}

function prompt_to_proceed_no () {
  ans=no
  if [ "$force" == "0" ]; then
    ans="no"
    while true; do
      echo -en "${CYAN}> $1 [yN]: ${NC}"
      read -p "" yn
      case $yn in
        [Yy]* ) ans=yes; break;;
        [Nn]* ) ans=no; break;;
        * ) ans=no; break;;
      esac
    done
  else
    echo -e "${CYAN}> $1 [yN]: N ${NC}"
  fi
}

prompt_to_proceed_yes "Remove all node services"
if [ "$ans" == "yes" ]; then
  n=$(docker service ls --filter name=$SVC_NAME-1 | grep -v '^ID' | wc -l)
  if [[ $n -gt 0 ]]; then
    docker service rm "$SVC_NAME-1"
  fi
  n=$(docker service ls --filter name=$SVC_NAME-2 | grep -v '^ID' | wc -l)
  if [[ $n -gt 0 ]]; then
    docker service rm "$SVC_NAME-2"
  fi
  n=$(docker service ls --filter name=$SVC_NAME-3 | grep -v '^ID' | wc -l)
  if [[ $n -gt 0 ]]; then
    docker service rm "$SVC_NAME-3"
  fi
fi

prompt_to_proceed_yes "Prune unused volumes"
if [ "$ans" == "yes" ]; then
  docker volume prune -f
fi

prompt_to_proceed_yes "Remove network"
if [ "$ans" == "yes" ]; then
  n=$(docker network ls --filter name=$NET_NAME | grep -v '^NETWORK' | wc -l)
  if [[ $n -gt 0 ]]; then
    docker network rm $NET_NAME
  fi
fi
