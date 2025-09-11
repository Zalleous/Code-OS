#!/bin/bash

resetUI() {
  clear
  echo "================================================"
  timedatectl
  echo -e "===============================================\n"
}

resetUI

###########################################

setupClock() {
  timezones=$(timedatectl list-timezones)
  
  PS3="Select your region : ";
  options=$(echo "$timezones" | cut -d'/' -f1 | sort -u)

  select region in $options; do
    if [[ -n "$region" ]]; then
      break
    else
      echo "Invalid index, -> 'i')"
    fi
  done

  resetUI

  PS3="Choice your zone: ";
  options2=$(echo "$timezones" | grep "^$region" | cut -d'/' -f2)

  select zone in $options2; do
    if [[ -n "$zone" ]]; then
      sudo timedatectl set-timezone "$region/$zone"
      sudo timedatectl set-ntp true
      sudo hwclock --systohc
      resetUI
      break
    else
      echo "Invalid index, -> 'i')"
    fi
  done;
}

#########################################

while true; do
  read -p "Do you want to change timezone ? (y/n)" yesNo
  
  case "$yesNo" in
    [Y/y]*) setupClock; break ;;
    [N/n]*) break ;;
    *) echo "Please answer y/Y or n/N" ;;
  esac
done

########################################
