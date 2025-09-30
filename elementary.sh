#!/usr/bin/env bash

# --- Default Settings ---
SLEEP_DURATION=0.01 # Time in seconds between lines
USE_RANDOM_SEED=0   # 0 = false (middle seed), 1 = true (random seed)
USE_TOROIDAL=0    # 0 = false (fixed boundaries), 1 = true (wrap around)
RULE_ARG=""         # Placeholder for rule number argument
generation_count=0  # Counter for generations

print_usage() {
  echo "Usage: $0 [-r] [-t] [RULE_NUMBER]" >&2
  echo "  -r : Use a random starting cell instead of the middle one." >&2
  echo "  -t : Use toroidal (wrap-around) boundaries." >&2
  echo "  RULE_NUMBER : Elementary CA rule (0-255). If omitted, uses random rule." >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r) USE_RANDOM_SEED=1; shift ;;
    -t) USE_TOROIDAL=1; shift ;;
    -h|--help) print_usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
    *)
      if [[ -z "$RULE_ARG" ]]; then RULE_ARG="$1"; else echo "Ignoring extra argument: $1" >&2; fi
      shift ;;
  esac
done

# --- Terminal Setup & Globals ---
cols=$(tput cols)
current_line="" # Holds the current generation's state

# --- Determine Rule ---
if [[ -z "$RULE_ARG" ]]; then
   RULE=$((RANDOM % 256))
else
   if [[ "$RULE_ARG" =~ ^[0-9]+$ ]] && (( "$RULE_ARG" >= 0 && "$RULE_ARG" <= 255 )); then
      RULE=$RULE_ARG
   else
      echo "Error: Rule must be an integer between 0 and 255. Got: '$RULE_ARG'" >&2
      exit 1
   fi
fi

# --- Cell Appearance ---
LIVE_CELL="O"
DEAD_CELL="."

check_unicode_support() {
   local charmap
   if command -v locale >/dev/null 2>&1; then
      charmap=$(locale charmap 2>/dev/null);
      if [[ "${charmap^^}" == "UTF-8" ]]; then LIVE_CELL="█"; DEAD_CELL=" "; return 0; fi
   fi
   if [[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" == *.UTF-8 ]]; then LIVE_CELL="█"; DEAD_CELL=" "; return 0; fi
   return 1
}
check_unicode_support
if [[ $? -ne 0 ]]; then DEAD_CELL="#"; fi

# --- Terminal Control ---
init() {
   printf '\e[?1049h'; printf '\e[?25l'; tput clear
}

cleanup() {
   # Restore title to default (empty string usually works)
   printf '\e]0;\a'
   printf '\e[?25h'; printf '\e[?1049l'
   exit 0
}
trap cleanup EXIT INT TERM QUIT

update_title() {
    local gen_num=$1 # Pass generation number
    local bounds_type="Fixed"
    local seed_type="Middle"

    (( USE_TOROIDAL == 1 )) && bounds_type="Toroid"
    (( USE_RANDOM_SEED == 1 )) && seed_type="Random"

    local title_string="ECA Gen: ${gen_num} | Rule: ${RULE} | Bounds: ${bounds_type} | Seed: ${seed_type}"

    printf '\e]0;%s\a' "$title_string"
}


create_seed() {
   current_line=""; for ((i = 0; i < cols; i++)); do current_line+="$DEAD_CELL"; done
   if ((cols > 0)); then
      local middle=$((cols / 2)); [[ $middle -lt 0 ]] && middle=0
      current_line="${current_line:0:$middle}${LIVE_CELL}${current_line:$((middle + 1))}"
   fi
}
create_random_seed() {
   current_line=""; for ((i = 0; i < cols; i++)); do current_line+="$DEAD_CELL"; done
   if ((cols > 0)); then
      local pos=$((RANDOM % cols))
      current_line="${current_line:0:$pos}${LIVE_CELL}${current_line:$((pos + 1))}"
   fi
}

main() {
   init
   update_title "$generation_count"

   if (( USE_RANDOM_SEED == 1 )); then create_random_seed; else create_seed; fi

   echo "$current_line"

   while true; do
      current_line=$(echo "$current_line" | awk -v RULE="$RULE" -v LIVE="$LIVE_CELL" -v DEAD="$DEAD_CELL" -v TOROIDAL="$USE_TOROIDAL" -v COLS="$cols" '
      {
         line = $0
         next_line = ""
         
         for (i = 1; i <= COLS; i++) {
            # Get current cell
            c_char = substr(line, i, 1)
            if (c_char == LIVE) {
               c = 1
            } else {
               c = 0
            }
            
            # Get left and right neighbors
            if (TOROIDAL == 1) {
               l_idx = (i - 2 + COLS) % COLS + 1
               r_idx = (i % COLS) + 1
            } else {
               l_idx = (i == 1) ? 0 : i - 1
               r_idx = (i == COLS) ? 0 : i + 1
            }
            
            if (l_idx == 0) {
               l = 0
            } else {
               l_char = substr(line, l_idx, 1)
               if (l_char == LIVE) {
                  l = 1
               } else {
                  l = 0
               }
            }
            
            if (r_idx == 0) {
               r = 0
            } else {
               r_char = substr(line, r_idx, 1)
               if (r_char == LIVE) {
                  r = 1
               } else {
                  r = 0
               }
            }
            
            # Calculate next state using rule - extract bit at position index
            pattern_idx = l*4 + c*2 + r
            # Use bit extraction: repeatedly divide a copy of RULE
            rule_copy = RULE
            for (j = 0; j < pattern_idx; j++) {
               rule_copy = int(rule_copy / 2)
            }
            next_state_bit = rule_copy % 2
            
            if (next_state_bit == 1) {
               next_line = next_line LIVE
            } else {
               next_line = next_line DEAD
            }
         }
         
         print next_line
      }')

      echo "$current_line"

      ((generation_count++))

      update_title "$generation_count"

      if read -r -N 1 -t "$SLEEP_DURATION" key; then break; fi
   done
}

main
