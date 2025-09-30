#!/usr/bin/env bash
# Brian Silverman’s “Seeds” in Bash + awk

SLEEP_DURATION=0.01 # delay between generations
INITIAL_SEEDS=100   # random live cells at start
LIVE_CELL="█"       # falls back to 'O' if no UTF‑8
DEAD_CELL=" "       # falls back to '.'

rows=$(tput lines) # cache size *before* we switch to alt‑screen
cols=$(tput cols)

check_unicode() {
    locale charmap 2>/dev/null | grep -qiF utf-8
}
check_unicode || {
    LIVE_CELL="O"
    DEAD_CELL="."
}

enter_alt() { printf '\e[?1049h\e[?25l'; } # alt‑screen & hide cursor
leave_alt() { printf '\e[?25h\e[?1049l'; } # restore
cleanup() {
    leave_alt
    stty echo
    exit
}
trap cleanup INT TERM EXIT

# ── grid containers ──────────────────────────────────────────────────────────
declare -gA FRONT BACK

swap_grids() {
    FRONT=()
    for k in "${!BACK[@]}"; do FRONT["$k"]=1; done
}

init_grid() {
    FRONT=()
    BACK=()
    local i r c
    for ((i = 0; i < INITIAL_SEEDS; ++i)); do
        r=$((RANDOM % rows))
        c=$((RANDOM % cols))
        FRONT["$r,$c"]=1
    done
}

update_grid() {
    BACK=()

    while IFS= read -r key; do # this loop is now
        BACK["$key"]=1         # in *this* shell
    done < <(
        printf '%s\n' "${!FRONT[@]}" |
            awk -v R="$rows" -v C="$cols" '
            BEGIN { FS="," }
            {
                live[$0]=1
                split($0, rc, ","); r=rc[1]; c=rc[2]
                for (dr=-1; dr<=1; dr++)
                    for (dc=-1; dc<=1; dc++) {
                        nr=(r+dr+R)%R; nc=(c+dc+C)%C
                        neigh[nr","nc]++
                    }
            }
            END {
                for (k in neigh)
                    if (!(k in live) && neigh[k]==2)
                        print k
            }'
    )
}

draw_diff() {
    local key r c out=""
    # cells that died
    for key in "${!FRONT[@]}"; do
        [[ -v BACK["$key"] ]] && continue
        IFS=',' read -r r c <<<"$key"
        out+="\e[$((r + 1));$((c + 1))H$DEAD_CELL"
    done
    # cells that were born
    for key in "${!BACK[@]}"; do
        [[ -v FRONT["$key"] ]] && continue
        IFS=',' read -r r c <<<"$key"
        out+="\e[$((r + 1));$((c + 1))H$LIVE_CELL"
    done
    # move cursor to bottom‑right so it doesn’t hide a cell
    out+="\e[$rows;${cols}H"
    printf '%b' "$out"
}

main() {
    enter_alt
    clear
    init_grid
    # itial frame (batched so it flushes once)
    local key r c buf=""
    for key in "${!FRONT[@]}"; do
        IFS=',' read -r r c <<<"$key"
        buf+="\e[$((r + 1));$((c + 1))H$LIVE_CELL"
    done
    buf+="\e[$rows;${cols}H"
    printf '%b' "$buf"

    # ── main loop ─────────────────────────────────────────────────────────────
    local ch
    while :; do
        update_grid
        draw_diff
        swap_grids
        # break on any key
        read -rsn1 -t "$SLEEP_DURATION" ch && break
    done
}

main
