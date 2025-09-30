#!/usr/bin/env bash

# --- Configuration ---
INITIAL_DENSITY=20 # Percentage of initially live cells (approx)
SLEEP_DURATION=0.001

# --- Terminal Setup & Globals ---
rows=$(tput lines)
cols=$(tput cols)

declare -A front # Current generation grid
declare -A back  # Next generation grid (buffer)

# --- Cell Appearance ---
# Default to ASCII
LIVE_CELL="O"
DEAD_CELL="."

# Attempt to detect UTF-8 locale for nicer characters
check_unicode_support() {
    local charmap
    # Check locale command first
    if command -v locale >/dev/null 2>&1; then
        charmap=$(locale charmap 2>/dev/null)
        if [[ "${charmap^^}" == "UTF-8" ]]; then
            LIVE_CELL="█" # Full Block U+2588
            DEAD_CELL=" " # Space
            return 0      # Indicate success
        fi
    fi
    # Fallback check if locale command missing or not UTF-8
    if [[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" == *.UTF-8 ]]; then
        LIVE_CELL="█"
        DEAD_CELL=" "
        return 0 # Indicate success
    fi
    return 1 # Indicate ASCII fallback
}
check_unicode_support
# Make DEAD_CELL visible if we fell back to ASCII
if [[ $? -ne 0 ]]; then
    DEAD_CELL="."
fi

init() {
    printf '\e[?1049h'
    printf '\e[?25l'
    clear
}

cleanup() {
    while read -r -t 0.001 -N 1; do :; done
    printf '\e[?25h'
    printf '\e[?1049l'
    exit 0
}

trap cleanup EXIT INT TERM QUIT # Set up cleanup on exit/interrupt

init_grid() {
    local r c num_cells target_cells
    front=() # Clear the front grid
    target_cells=$((rows * cols * INITIAL_DENSITY / 100))
    [[ $target_cells -lt 0 ]] && target_cells=0

    for ((num_cells = 0; num_cells < target_cells; num_cells++)); do
        r=$((RANDOM % rows))
        c=$((RANDOM % cols))
        front["$r,$c"]=1
    done
}

update_grid() {
    back=()
    
    # Use awk to process Conway's Game of Life rules
    while IFS= read -r key; do
        back["$key"]=1
    done < <(
        printf '%s\n' "${!front[@]}" |
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
                    if (dr == 0 && dc == 0) continue  # Skip the cell itself
                    nr = (r + dr + R) % R
                    nc = (c + dc + C) % C
                    neighbor_pos = nr "," nc
                    neighbor_count[neighbor_pos]++
                }
            }
        }
        END {
            # Apply Conway'\''s Game of Life rules:
            # Birth: exactly 3 neighbors
            # Survival: 2 or 3 neighbors
            for (pos in neighbor_count) {
                count = neighbor_count[pos]
                if (pos in alive) {
                    # Alive cell survives with 2 or 3 neighbors
                    if (count == 2 || count == 3) {
                        print pos
                    }
                } else {
                    # Dead cell becomes alive with exactly 3 neighbors
                    if (count == 3) {
                        print pos
                    }
                }
            }
        }'
    )
}



# Draw the changes using ANSI escapes and batched output
draw_grid() {
    local key r c
    local draw_buffer=""

    # Cells that died (in front but not in back)
    for key in "${!front[@]}"; do
        if [[ ! -v back["$key"] ]]; then
            IFS=',' read -r r c <<<"$key"
            draw_buffer+="\e[$((r + 1));$((c + 1))H${DEAD_CELL}"
        fi
    done

    # Cells that were born or survived (in back)
    for key in "${!back[@]}"; do
        # Optimization: Only draw if it wasn't already alive (reduces overdraw)
        if [[ ! -v front["$key"] ]]; then
            IFS=',' read -r r c <<<"$key"
            draw_buffer+="\e[$((r + 1));$((c + 1))H${LIVE_CELL}"
        fi
    done

    draw_buffer+="\e[$((rows));$((cols))H"

    # Print the entire buffer at once
    printf "%b" "$draw_buffer"
}

swap() {
    front=()
    for key in "${!back[@]}"; do
        front["$key"]="${back[$key]}"
    done

}

main() {
    init
    init_grid

    # Initial draw (draw all live cells from the start using ANSI batching)
    clear # Clear screen once initially
    local initial_draw_buffer=""
    for key in "${!front[@]}"; do
        IFS=',' read -r r c <<<"$key"
        initial_draw_buffer+="\e[$((r + 1));$((c + 1))H${LIVE_CELL}"
    done
    initial_draw_buffer+="\e[$((rows));$((cols))H" # Move cursor away
    printf "%b" "$initial_draw_buffer"             # Print initial state

    while true; do
        update_grid
        draw_grid
        swap

        if read -r -N 1 -t "$SLEEP_DURATION" key; then
            break # Exit loop if key pressed
        fi
    done
}

main
