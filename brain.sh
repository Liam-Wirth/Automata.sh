#!/usr/bin/env bash

# Implementation of Brian's Brain in shell
# Brian's Brain is a 3-state cellular automaton:
# - Dead (0): implicit (not in any array)
# - Alive (1): birth and lives for one generation
# - Dying (2): transition state before death

# --- Configuration ---
INITIAL_DENSITY=10  # Percentage of initially alive cells
SLEEP_DURATION=0.01 # Animation speed

# --- Terminal Setup & Globals ---
rows=$(tput lines)
cols=$(tput cols)

declare -A alive_cells    # State 1: cells that are alive
declare -A dying_cells    # State 2: cells that are dying
declare -A next_alive     # Next generation alive cells
declare -A next_dying     # Next generation dying cells

# --- Cell Appearance ---
ALIVE_CELL="█"  # State 1: fully alive (bright)
DYING_CELL="▓"  # State 2: dying (dimmer)
DEAD_CELL=" "   # State 0: dead (empty)

# Check for Unicode support and fallback to ASCII if needed
check_unicode_support() {
    local charmap
    if command -v locale >/dev/null 2>&1; then
        charmap=$(locale charmap 2>/dev/null)
        if [[ "${charmap^^}" == "UTF-8" ]]; then
            return 0
        fi
    fi
    if [[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" == *.UTF-8 ]]; then
        return 0
    fi
    return 1
}

# terminal compat
if ! check_unicode_support; then
    ALIVE_CELL="O"  # ASCII fallback for alive
    DYING_CELL="o"  # ASCII fallback for dying (lowercase)
    DEAD_CELL="."   # ASCII fallback for dead
fi

# --- Terminal Control ---
init_terminal() {
    printf '\e[?1049h'  # Switch to alternate screen
    printf '\e[?25l'    # Hide cursor
    clear
}

cleanup() {
    printf '\e[?25h'    # Show cursor
    printf '\e[?1049l'  # Switch back to main screen
    exit 0
}

trap cleanup EXIT INT TERM QUIT


# --- Grid Operations ---


update_grid() {
    next_alive=()
    next_dying=()
    
    # Process alive -> dying transitions (all alive cells become dying)
    for key in "${!alive_cells[@]}"; do
        next_dying["$key"]=1
    done
    
    # Use awk to find cells that should become alive
    while IFS= read -r key; do
        next_alive["$key"]=1
    done < <(
        printf '%s\n' "${!alive_cells[@]}" |
        awk -v R="$rows" -v C="$cols" '
        BEGIN { FS="," }
        {
            # Mark alive cells
            alive[$0] = 1
            split($0, rc, ",")
            r = rc[1]
            c = rc[2]
            
            # Count neighbors for all cells around alive cells
            for (dr = -1; dr <= 1; dr++) {
                for (dc = -1; dc <= 1; dc++) {
                    nr = (r + dr + R) % R
                    nc = (c + dc + C) % C
                    neigh[nr "," nc]++
                }
            }
        }
        END {
            # Find cells that should become alive (exactly 2 alive neighbors and not currently alive)
            for (pos in neigh) {
                if (!(pos in alive) && neigh[pos] == 2) {
                    print pos
                }
            }
        }'
    )
}

# think of this like a double buffer
swap_grids() {
    alive_cells=()
    dying_cells=()
    
    for key in "${!next_alive[@]}"; do
        alive_cells["$key"]=1
    done
    
    for key in "${!next_dying[@]}"; do
        dying_cells["$key"]=1
    done
}

draw_grid() {
    local key r c draw_buffer=""
    
    for key in "${!dying_cells[@]}"; do
        if [[ ! -v next_dying["$key"] ]]; then
            IFS=',' read -r r c <<< "$key"
            draw_buffer+="\e[$((r + 1));$((c + 1))H${DEAD_CELL}"
        fi
    done
    
    for key in "${!next_dying[@]}"; do
        if [[ ! -v dying_cells["$key"] ]]; then
            IFS=',' read -r r c <<< "$key"
            draw_buffer+="\e[$((r + 1));$((c + 1))H${DYING_CELL}"
        fi
    done
    
    for key in "${!next_alive[@]}"; do
        if [[ ! -v alive_cells["$key"] ]]; then
            IFS=',' read -r r c <<< "$key"
            draw_buffer+="\e[$((r + 1));$((c + 1))H${ALIVE_CELL}"
        fi
    done
    
    draw_buffer+="\e[$rows;${cols}H"
    
    printf "%b" "$draw_buffer"
}

init_grid() {
    local num_cells target_cells r c
    
    # Clear all arrays
    alive_cells=()
    dying_cells=()
    next_alive=()
    next_dying=()
    
    target_cells=$((rows * cols * INITIAL_DENSITY / 100))
    [[ $target_cells -lt 1 ]] && target_cells=1
    
    for ((num_cells = 0; num_cells < target_cells; num_cells++)); do
        r=$((RANDOM % rows))
        c=$((RANDOM % cols))
        alive_cells["$r,$c"]=1
    done
}

draw_initial() {
    local key r c draw_buffer=""
    
    for key in "${!alive_cells[@]}"; do
        IFS=',' read -r r c <<< "$key"
        draw_buffer+="\e[$((r + 1));$((c + 1))H${ALIVE_CELL}"
    done
    
    for key in "${!dying_cells[@]}"; do
        IFS=',' read -r r c <<< "$key"
        draw_buffer+="\e[$((r + 1));$((c + 1))H${DYING_CELL}"
    done
    
    draw_buffer+="\e[$rows;${cols}H"
    
    printf "%b" "$draw_buffer"
}

main() {
    init_terminal
    init_grid
    draw_initial
    
    while true; do
        update_grid
        draw_grid
        swap_grids
        
        if read -r -N 1 -t "$SLEEP_DURATION" key; then
            break
        fi
    done
}

main
