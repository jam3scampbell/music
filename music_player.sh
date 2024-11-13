#!/bin/zsh

# Required dependencies: mpv youtube-dl

SOCKET_PATH=/tmp/mpvsocket
CURRENT_PLAYLIST=playlist.txt  # Default playlist

# Aliases for common commands - all prefixed with 'm' to avoid conflicts
alias mx="play_song"         # Music play by number/name
alias mn="next_song"         # Music next
alias mp="previous_song"     # Music previous
alias mt="toggle_pause"      # Music toggle play/pause
alias ms="show_live_status"  # Music status
alias ml="list_songs"        # Music list
alias mpl="list_playlists"   # Music playlist list
alias msw="switch_playlist"  # Music switch playlist
alias mf="seek_forward"      # Music forward 30s
alias mb="seek_backward"     # Music back 30s
alias msh="shuffle_play"     # Music shuffle
alias hlp="quick_help"    # Quick help for aliases

# Function to start mpv with proper options
start_mpv() {
    local playlist=$1
    mpv --no-video --really-quiet --input-ipc-server=${SOCKET_PATH} --playlist="$playlist" &
    sleep 0.1
}

# Helper function to get a property from mpv
get_mpv_property() {
    local property=$1
    local cmd='{"command": ["get_property", "'
    local end='"]}'
    echo "$cmd$property$end" | \
        socat - ${SOCKET_PATH} 2>/dev/null | \
        grep -o '"data":[^,}]*' | \
        cut -d':' -f2
}

# Function to list available playlists
list_playlists() {
    echo "Available playlists:"
    echo "Current playlist: $CURRENT_PLAYLIST"
    echo "------------------------"
    ls -1 *.txt
}

switch_playlist() {
    local playlist_name=$1
    if [ -z "$playlist_name" ]; then
        echo "Please specify a playlist name"
        list_playlists
        return 1
    fi
    case "$playlist_name" in
        *.txt) ;;
        *) playlist_name=$playlist_name.txt ;;
    esac

    if [ -f "$playlist_name" ]; then
        CURRENT_PLAYLIST="$playlist_name"
        echo "Switched to playlist: $playlist_name"
        stop_playback
    else
        echo "Playlist not found: $playlist_name"
        list_playlists
        return 1
    fi
}

# Function to create a new playlist
create_playlist() {
    local playlist_name=$1
    if [[ -z "$playlist_name" ]]; then
        echo "Please specify a playlist name"
        return 1
    fi
    
    # If just the name is given without .txt, append it
    if [[ ! $playlist_name =~ \.txt$ ]]; then
        playlist_name="${playlist_name}.txt"
    fi
    
    if [[ ! -f "$playlist_name" ]]; then
        touch "$playlist_name"
        echo "Created new playlist: $playlist_name"
    else
        echo "Playlist already exists: $playlist_name"
        return 1
    fi
}

# Function to start mpv if it's not running
ensure_player_running() {
    if ! pgrep -f "mpv.*${SOCKET_PATH}" > /dev/null; then
        cleanup_tmp_files
        awk -F' *\\| *' '{print $2}' "$CURRENT_PLAYLIST" | tr -d ' ' > /tmp/current_playlist.txt
        start_mpv "/tmp/current_playlist.txt"
    fi
}

# Function to list all songs with their labels and indices
list_songs() {
    echo "Available songs in $CURRENT_PLAYLIST:"
    awk -F' | ' '{print NR ". " $1}' "$CURRENT_PLAYLIST"
}

play_song() {
    local search=$1
    if [[ -z "$search" ]]; then
        echo "Please provide a song label or number"
        list_songs
        return 1
    fi

    # If numeric, play that line number
    if [[ "$search" =~ ^[0-9]+$ ]]; then
        local url=$(awk -F' *\\| *' "NR==$search {print \$2}" "$CURRENT_PLAYLIST" | tr -d ' ')
        local title=$(awk -F' *\\| *' "NR==$search {print \$1}" "$CURRENT_PLAYLIST")
    else
        # Otherwise search for label
        local url=$(awk -F' *\\| *' "\$1 ~ /$search/ {print \$2; exit}" "$CURRENT_PLAYLIST" | tr -d ' ')
        local title=$(awk -F' *\\| *' "\$1 ~ /$search/ {print \$1; exit}" "$CURRENT_PLAYLIST")
    fi

    if [[ -z "$url" ]]; then
        echo "Song not found"
        list_songs
        return 1
    fi

    if pgrep -f "mpv.*${SOCKET_PATH}" > /dev/null; then
        pkill -f "mpv.*${SOCKET_PATH}"
        sleep 0.1
    fi

    # Instead of playing just this song, create a playlist starting from this song
    if [[ "$search" =~ ^[0-9]+$ ]]; then
        # If numeric, start playlist from this number
        awk -F' *\\| *' -v start="$search" 'NR>=start {print $2}' "$CURRENT_PLAYLIST" | tr -d ' ' > /tmp/current_playlist.txt
        # Also add the songs before it at the end for wraparound
        awk -F' *\\| *' -v start="$search" 'NR<start {print $2}' "$CURRENT_PLAYLIST" | tr -d ' ' >> /tmp/current_playlist.txt
    else
        # If label search, find the line number first
        local line_num=$(awk -F' *\\| *' "\$1 ~ /$search/ {print NR; exit}" "$CURRENT_PLAYLIST")
        awk -F' *\\| *' -v start="$line_num" 'NR>=start {print $2}' "$CURRENT_PLAYLIST" | tr -d ' ' > /tmp/current_playlist.txt
        awk -F' *\\| *' -v start="$line_num" 'NR<start {print $2}' "$CURRENT_PLAYLIST" | tr -d ' ' >> /tmp/current_playlist.txt
    fi

    echo "Playing: $title"
    start_mpv "/tmp/current_playlist.txt"
    echo "Use 'ms' or 'show_live_status' for live playback display"
}


# Function to play entire playlist
play_playlist() {
    ensure_player_running
    echo "Playlist started in background. Use other commands to control playback."
    echo "Use 'ms' or 'show_live_status' for live playback display"
    list_songs
}

# Cleanup function
cleanup_tmp_files() {
    rm -f /tmp/current_playlist.txt /tmp/shuffled_playlist.txt /tmp/shuffled_full.txt
}

# Function to ensure cleanup happens on exit
setup_cleanup() {
    trap cleanup_tmp_files EXIT
}

# Call setup_cleanup when the script is sourced
setup_cleanup

# Function to shuffle playlist
shuffle_play() {
    if pgrep -f "mpv.*${SOCKET_PATH}" > /dev/null; then
        pkill -f "mpv.*${SOCKET_PATH}"
        sleep 1
    fi
    
    cleanup_tmp_files
    
    # Create shuffled playlist using shuf for better randomization
    awk -F' *\\| *' '{print $0}' "$CURRENT_PLAYLIST" | \
        shuf | \
        awk '{print NR ". " $0}' > /tmp/shuffled_full.txt
    
    # Extract URLs
    awk -F' *\\| *' '{print $2}' /tmp/shuffled_full.txt | tr -d ' ' > /tmp/shuffled_playlist.txt
    
    echo "Starting shuffled playlist..."
    start_mpv "/tmp/shuffled_playlist.txt"
    
    echo "Current shuffle order:"
    awk -F' *\\| *' '{print NR ". " $1}' /tmp/shuffled_full.txt
    echo "Use 'ms' or 'show_live_status' for live playback display"
}

# Function to show live status
show_live_status() {
    ensure_player_running
    echo "Press q to exit live status"
    echo -e "\033[?25l"  # Hide cursor
    
    # Save current terminal state
    stty -echo -icanon   # Set terminal to raw mode
    
    while true; do
        # Check for 'q' keypress immediately
        if read -t 0.1 -k 1 input; then
            if [[ "$input" == "q" ]]; then
                break
            fi
        fi
        
        # Clear previous lines and move cursor up
        echo -en "\r\033[K"  # Clear current line
        echo -en "\033[2A"   # Move up 2 lines
        
        local title=$(get_mpv_property "media-title")
        local position=$(get_mpv_property "time-pos")
        local duration=$(get_mpv_property "duration")
        
        # Format the display
        echo -en "\rNow Playing: $title\n"
        
        if [[ -n "$position" && "$position" != "null" && -n "$duration" && "$duration" != "null" ]]; then
            printf "\r[%d:%02d / %d:%02d]" $((position/60)) $((position%60)) $((duration/60)) $((duration%60))
            
            # Create progress bar
            local width=50
            local progress=$(( (position * width) / duration ))
            echo -n " ["
            for ((i=0; i<width; i++)); do
                if ((i < progress)); then
                    echo -n "="
                elif ((i == progress)); then
                    echo -n ">"
                else
                    echo -n " "
                fi
            done
            echo -n "]"
        else
            echo -en "\r[0:00 / 0:00] [                                                ]"
        fi
    done
    
    # Restore terminal state
    stty echo icanon
    
    echo -e "\n"  # Move to new line
    echo -e "\033[?25h"  # Show cursor
}

# Function to skip to next song
next_song() {
    ensure_player_running
    echo '{"command": ["playlist-next"]}' | socat - ${SOCKET_PATH} >/dev/null 2>&1
    sleep 0.1
    show_status
}

# Function to go to previous song
previous_song() {
    ensure_player_running
    echo '{"command": ["playlist-prev"]}' | socat - ${SOCKET_PATH} >/dev/null 2>&1
    sleep 0.1
    show_status
}

# Function to seek within current song
seek() {
    local amount=$1
    if [[ -z "$amount" ]]; then
        echo "Please specify seek amount (e.g., +30, -10, or absolute time like 1:30)"
        return 1
    fi

    ensure_player_running
    
    # Handle timestamp format (mm:ss)
    if [[ "$amount" =~ ^[0-9]+:[0-9]+$ ]]; then
        local minutes=$(echo $amount | cut -d: -f1)
        local seconds=$(echo $amount | cut -d: -f2)
        local total_seconds=$((minutes * 60 + seconds))
        echo "{\"command\": [\"seek\", $total_seconds, \"absolute\"]}" | socat - ${SOCKET_PATH} >/dev/null 2>&1
    else
        # Handle relative seeking (+/- seconds)
        echo "{\"command\": [\"seek\", \"$amount\"]}" | socat - ${SOCKET_PATH} >/dev/null 2>&1
    fi
    
    sleep 0.1
    show_status
}

# Quick seek shortcuts
seek_forward() {
    seek "+30"
    echo "Skipped forward 30 seconds"
}

seek_backward() {
    seek "-30"
    echo "Skipped backward 30 seconds"
}

# Function to pause/unpause
toggle_pause() {
    ensure_player_running
    echo '{"command": ["cycle", "pause"]}' | socat - ${SOCKET_PATH} >/dev/null 2>&1
    echo "Toggled pause/play"
}

# Function to adjust volume
adjust_volume() {
    local change=$1
    ensure_player_running
    echo "{\"command\": [\"add\", \"volume\", $change]}" | socat - ${SOCKET_PATH} >/dev/null 2>&1
    echo "Volume adjusted by $change"
}

# Function to stop playback
stop_playback() {
    if pgrep -f "mpv.*${SOCKET_PATH}" > /dev/null; then
        pkill -f "mpv.*${SOCKET_PATH}"
        echo "Playback stopped"
    else
        echo "No active playback to stop"
    fi
}

# Function to show current playback status
show_status() {
    ensure_player_running
    
    local title=$(get_mpv_property "media-title")
    local position=$(get_mpv_property "time-pos")
    local duration=$(get_mpv_property "duration")
    
    echo "Current track: $title"
    
    if [[ -n "$position" && "$position" != "null" ]]; then
        printf "Position: %d:%02d\n" $((position/60)) $((position%60))
    else
        echo "Position: 0:00"
    fi
    
    if [[ -n "$duration" && "$duration" != "null" ]]; then
        printf "Duration: %d:%02d\n" $((duration/60)) $((duration%60))
    else
        echo "Duration: Unknown"
    fi
}

quick_help() {
    cat << 'EOF'
Quick Commands:
  mx NUM/LABEL  - Play song (by number or name)
  mn/mp         - Next/Previous song
  mt           - Toggle play/pause
  ms           - Show live status
  ml           - List songs
  mpl          - List playlists
  msw NAME     - Switch playlist
  mf/mb        - Forward/Back 30s
  msh          - Shuffle play

EOF
}


# Function to show all available commands
help() {
    cat << 'EOF'
Music Player Commands:

Playback Control:
  play_song NUMBER   - Play song by number
  play_song 'LABEL'  - Play song by label search
  play_playlist      - Start playing full playlist
  shuffle_play       - Shuffle and play playlist
  next_song         - Skip to next song
  previous_song     - Go to previous song
  toggle_pause      - Pause/unpause playback
  stop_playback     - Stop playing

Navigation:
  seek +/-N         - Seek N seconds forward/backward
  seek mm:ss        - Seek to specific timestamp
  seek_forward      - Skip forward 30 seconds
  seek_backward     - Skip backward 30 seconds

Status and Information:
  show_status       - Show current track info
  show_live_status  - Show live updating display with progress bar
  list_songs        - Show all available songs

Playlist Management:
  list_playlists    - Show all available playlists
  switch PLAYLIST   - Switch to a different playlist (e.g., switch rock)
  create PLAYLIST   - Create a new empty playlist (e.g., create jazz)

Volume Control:
  adjust_volume +/-N - Adjust volume (e.g., adjust_volume +10)

Aliases (Shortcuts):
  mx NUMBER/LABEL    - Play song (mx for 'music play')
  mn                 - Next song
  mp                 - Previous song
  mt                 - Toggle play/pause
  ms                 - Show live status
  ml                 - List songs
  mpl               - List playlists
  msw PLAYLIST      - Switch playlist
  mf                - Forward 30s
  mb                - Back 30s
  msh               - Shuffle play

Tips:
- All playlists are .txt files in the current directory
- The live status display (ms) can be exited by pressing 'q'
- You can use partial matches for song labels (e.g., mx drak)

Examples:
  ml                        # List available songs
  mx 3                      # Play the third song
  mx drake_2                # Play first matching song
  shuffle_play              # Play playlist in random order
  seek 1:30                 # Jump to 1 minute 30 seconds
  seek +30                  # Skip forward 30 seconds
  status                    # Show live progress bar
  switch rock               # Switch to rock.txt playlist
  adjust_volume +10         # Increase volume
EOF
}
