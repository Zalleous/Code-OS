echo "================================================"
timedatectl
echo -e "===============================================\n"

###########################################

setupClock() {
  PS3 "Choice your timezone: "
  options=( $(timedatectl list-timezones) )
  select tz in "${options[@]}"; do
    if [[ -n "$tz" ]]; then
      sudo timedatectl set-timezone "$tz"
      sudo timedatectl set-ntp true
      sudo hwclock --systohc
      echo "set timezone to $tz"
      break
    else
      echo "Invalid index, -> 'i')"
    fi
  done
}

#########################################

while true; do
  read -p "Do you want to change timezone ? (y/n)" yesNo
  
  case "$yesNo" in
    [Y/y]*) echo "continue..."; setupClock; break ;;
    [N/n]*) break ;;
    *) echo "Please answer y/Y or n/N" ;;
  esac
done

########################################
