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
alias mv="adjust_volume"     # Music volume
alias ml="list_songs"        # Music list
alias mpl="list_playlists"   # Music playlist list
alias msw="switch_playlist"  # Music switch playlist
alias mf="seek_forward"      # Music forward 30s
alias mb="seek_backward"     # Music back 30s
alias msh="shuffle_play"     # Music shuffle

# Function to start mpv with proper options
start_mpv() {
    local playlist=$1
    mpv --no-video --really-quiet --input-ipc-server=${SOCKET_PATH} --playlist="$playlist" &
    sleep 1
}

# Helper function to get a property from mpv
get_mpv_property() {
    local property=$1
    echo '{"command": ["get_property", "'$property'"]}' | \
        socat - ${SOCKET_PATH} 2>/dev/null | \
        grep -o '"data":[^,}]*' | \
        sed 's/"data"://; s/"//g'
}

# Function to list available playlists
list_playlists() {
    echo "Available playlists:"
    echo "Current playlist: $CURRENT_PLAYLIST"
    echo "------------------------"
    ls -1 *.txt
}

# Function to switch to a different playlist
switch_playlist() {
    local playlist_name=$1
    if [[ -z "$playlist_name" ]]; then
        echo "Please specify a playlist name"
        list_playlists
        return 1
    fi
    
    # If just the name is given without .txt, append it
    if [[ ! $playlist_name =~ \.txt$ ]]; then
        playlist_name="${playlist_name}.txt"
    fi
    
    if [[ -f "$playlist_name" ]]; then
        CURRENT_PLAYLIST="$playlist_name"
        echo "Switched to playlist: $playlist_name"
        stop_playback  # Stop current playback when switching playlists
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

# Function to play a specific song by label or number
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
        sleep 1
    fi

    echo "Playing: $title"
    start_mpv <(echo "$url")
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
    local term_state
    stty -g > /dev/null 2>&1
    term_state=$?
    
    # Set terminal to raw mode
    stty raw -echo

    while true; do
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
        
        # Check for 'q' keypress
        if read -t 0.1 -N 1 input; then
            if [[ "$input" == "q" ]]; then
                break
            fi
        fi
    done
    
    # Restore terminal state
    if [[ $term_state -eq 0 ]]; then
        stty $(stty -g)
    fi
    
    echo -e "\n"  # Move to new line
    echo -e "\033[?25h"  # Show cursor
}

# Function to skip to next song
next_song() {
    ensure_player_running
    echo '{"command": ["playlist-next"]}' | socat - ${SOCKET_PATH} >/dev/null 2>&1
    sleep 1
    show_status
}

# Function to go to previous song
previous_song() {
    ensure_player_running
    echo '{"command": ["playlist-prev"]}' | socat - ${SOCKET_PATH} >/dev/null 2>&1
    sleep 1
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
    
    sleep 0.5
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

# Function to show all available commands
help() {
    echo "Music Player Commands:"
    echo ""
    echo "Playback Control:"
    echo "  play_song NUMBER   - Play song by number"
    echo "  play_song 'LABEL'  - Play song by label search"
    echo "  play_playlist      - Start playing full playlist"
    echo "  shuffle_play       - Shuffle and play playlist"
    echo "  next_song         - Skip to next song"
    echo "  previous_song     - Go to previous song"
    echo "  toggle_pause      - Pause/unpause playback"
    echo "  stop_playback     - Stop playing"
    echo ""
    echo "Navigation:"
    echo "  seek +/-N         - Seek N seconds forward/backward"
    echo "  seek mm:ss        - Seek to specific timestamp"
    echo "  seek_forward      - Skip forward 30 seconds"
    echo "  seek_backward     - Skip backward 30 seconds"
    echo ""
    echo "Status and Information:"
    echo "  show_status       - Show current track info"
    echo "  show_live_status  - Show live updating display with progress bar"
    echo "  list_songs        - Show all available songs"
    echo ""
    echo "Playlist Management:"
    echo "  list_playlists    - Show all available playlists"
    echo "  switch PLAYLIST   - Switch to a different playlist (e.g., switch rock)"
    echo "  create PLAYLIST   - Create a new empty playlist (e.g., create jazz)"
    echo ""
    echo "Volume Control:"
    echo "  adjust_volume +/-N - Adjust volume (e.g., adjust_volume +10)"
    echo ""
    echo "Aliases (Shortcuts):"
    echo "  mx NUMBER/LABEL    - Play song (mx for 'music play')"
    echo "  mn                 - Next song"
    echo "  mp                 - Previous song"
    echo "  mt                 - Toggle play/pause"
    echo "  ms                 - Show live status"
    echo "  mv +/-N           - Adjust volume"
    echo "  ml                 - List songs"
    echo "  mpl               - List playlists"
    echo "  msw PLAYLIST      - Switch playlist"
    echo "  mf                - Forward 30s"
    echo "  mb                - Back 30s"
    echo "  msh               - Shuffle play"
    echo ""
    echo "Tips:"
    echo "- All playlists are .txt files in the current directory"
    echo "- Use tab completion for playlist names with the switch command"
    echo "- The live status display (ms) can be exited by pressing 'q'"
    echo "- You can use partial matches for song labels (e.g., mx drak)"
    echo ""
    echo "Examples:"
    echo "  ml                        # List available songs"
    echo "  mx 3