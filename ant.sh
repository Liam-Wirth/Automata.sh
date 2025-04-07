#!/usr/bin/env bash

SLEEP_DURATION=0.001 # Adjusted for better visibility initially
ANT_CHAR="@"       # Character to represent the ant

rows=$(tput lines)
cols=$(tput cols)


SHOW_CURSOR='\e[?25h' # Show cursor
HIDE_CURSOR='\e[?25l' # Hide cursor
ALT_SCREEN='\e[?1049h' # Enter alternate screen buffer
RESET_SCREEN='\e[?1049l' # Exit alternate screen buffer

declare -A grid # Stores the black cells: grid["row,col"]=1

# --- Unicode/Character Setup ---
LIVE_CELL="█" # Default to Unicode Block
DEAD_CELL=" " # Default to Space
ANT_CHAR="☺"

# Attempt to detect UTF-8 locale for nicer characters
check_unicode_support() {
    local charmap
    # Check locale command first
    if command -v locale >/dev/null 2>&1; then
        charmap=$(locale charmap 2>/dev/null)
        if [[ "${charmap^^}" == "UTF-8" ]]; then
            return 0 # Indicate success (use defaults)
        fi
    fi
    # Fallback check if locale command missing or not UTF-8
    if [[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" == *.UTF-8 ]]; then
        return 0 # Indicate success (use defaults)
    fi
    # If neither worked, fall back to ASCII
    LIVE_CELL="#"
    DEAD_CELL="."
    return 1 # Indicate ASCII fallback
}
check_unicode_support

init() {
    printf '%s' "$ALT_SCREEN"
    printf '%s' "$HIDE_CURSOR"
    clear            
}

cleanup() {
    printf '%s' "$SHOW_CURSOR"
    printf '%s' "$RESET_SCREEN"
    exit 0
}

trap cleanup EXIT INT TERM QUIT

declare -a ant_pos

# Ant direction: 0=Up, 1=Right, 2=Down, 3=Left
ant_dir_idx=0
# Direction vectors (dr, dc) corresponding to the index
#             Up       Right    Down     Left
dirs=(-1 0    0 1    1 0    0 -1)

init_grid() {
    grid=()
    ant_pos=($((rows / 2)) $((cols / 2)))
}

step() {
    local r=${ant_pos[0]}
    local c=${ant_pos[1]}
    local current_cell_key="${r},${c}"
    local dr dc next_r next_c

    # We don't need old_r/old_c here anymore for echoing
    local old_cell_state=${grid[$current_cell_key]:-0} # 0 for white (unset), 1 for black

    if [[ $old_cell_state -eq 0 ]]; then # White square
        grid["$current_cell_key"]=1        # Flip to black
        ant_dir_idx=$(( (ant_dir_idx + 1) % 4 )) # Turn 90 degrees right
    else # Black square
        unset grid["$current_cell_key"]   # Flip to white
        ant_dir_idx=$(( (ant_dir_idx + 3) % 4 )) # Turn 90 degrees left (add 3 is same as sub 1 mod 4)
    fi

    dr=${dirs[ant_dir_idx * 2]}
    dc=${dirs[ant_dir_idx * 2 + 1]}

    # Add rows/cols before modulo to handle potential negative results correctly in bash
    next_r=$(( (r + dr + rows) % rows ))
    next_c=$(( (c + dc + cols) % cols ))

    # Move ant to the next position
    ant_pos=("$next_r" "$next_c")

}

# --- Drawing ---
# Draws only the changes: the cell the ant left and the new ant position
draw_changes() {
    local old_r=$1
    local old_c=$2
    local new_color_at_old=$3 # 0 for white, 1 for black
    local new_ant_r=$4
    local new_ant_c=$5
    local draw_buffer=""

    local cell_char_at_old
    if [[ $new_color_at_old -eq 1 ]]; then
        cell_char_at_old="$LIVE_CELL"
    else
        cell_char_at_old="$DEAD_CELL"
    fi
    # ANSI: \e[row;colH - Note: rows/cols are 1-based in ANSI
    draw_buffer+="\e[$((old_r + 1));$((old_c + 1))H${cell_char_at_old}"

    # 2. Draw the ant at its new position
    draw_buffer+="\e[$((new_ant_r + 1));$((new_ant_c + 1))H${ANT_CHAR}"

    # Move cursor out of the way (e.g., to bottom right)
    draw_buffer+="\e[${rows};${cols}H"

    # Print the entire buffer at once
    printf "%b" "$draw_buffer"
}

main() {
    init
    init_grid

    # Initial draw: draw the ant at its starting position
    printf "\e[$(( ${ant_pos[0]} + 1 ));$(( ${ant_pos[1]} + 1 ))H${ANT_CHAR}"
    printf "\e[${rows};${cols}H" # Move cursor away

    while true; do
        # Store previous state needed for drawing
        local prev_ant_pos=("${ant_pos[@]}") # Store where the ant WAS

        # Perform one step IN THE CURRENT SHELL to update global state
        step

        # --- Determine values for draw_changes ---
        local old_r=${prev_ant_pos[0]}
        local old_c=${prev_ant_pos[1]}
        local new_ant_r=${ant_pos[0]} # Get ant's NEW position from global state
        local new_ant_c=${ant_pos[1]} # Get ant's NEW position from global state

        # Find the NEW color of the cell the ant just LEFT.
        # Check the updated grid at the old position. Default to 0 (white) if unset.
        local new_color_at_old=${grid[${old_r},${old_c}]:-0}

        # --- Draw the changes ---
        draw_changes "$old_r" "$old_c" "$new_color_at_old" "$new_ant_r" "$new_ant_c"

        # Check for user input to exit, with sleep
        if read -r -N 1 -t "$SLEEP_DURATION" key; then
            break # Exit loop if key pressed
        fi
    done
}

# --- Run ---
main
