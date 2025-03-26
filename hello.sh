#!/usr/bin/env bash

rows=$(($(tput lines) - 1))
cols=$(($(tput cols) - 1))

declare -A front
declare -A back


print_centered() {
   local text="$1"
   local text_len=${#text}

   local center_row=$((rows / 2))
   local center_col=$(((cols - text_len) / 2))

   tput cup "$center_row" "$center_col"
   echo "$text"

}

init() {
   tput smcup # save the terminal to an alternate screen
   tput civis # hide the cursor
   clear
}


cleanup() {
   #clear out stdin:
   read -t 0.001 && cat </dev/stdin>/dev/null
   tput reset
   tput rmcup #restore from the alternate screen
   tput cnorm
   exit 0
}

trap cleanup EXIT INT TERM QUIT #This sets 
main() {
   init
   print_centered "Hello World!"
   echo ""
   read -n 1
}

main
