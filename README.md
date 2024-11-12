# Command Line Music Player

A true hacker must never touch the mouse. This script provides terminal commands that emulate a Spotify-like music player. Songs are saved as YouTube links in txt files. Each txt file is a playlist.

## Setup

### Prerequisites
```bash
# On macOS with homebrew:
brew install mpv youtube-dl socat

# On Ubuntu/Debian:
sudo apt install mpv youtube-dl socat
```

### Installation
1. Make the script executable: `chmod +x music_player.sh`
2. Create a playlist file named `playlist.txt` with format:
```
song_label | https://www.youtube.com/watch?v=...
another_song | https://www.youtube.com/watch?v=...
```
3. Source the script: `source music_player.sh`

## Commands and Aliases

### Playback Control
```bash
# Play a specific song
play_song 3        # Full command
mx 3              # Quick alias
                  # Both play the third song in playlist

play_song drake_2  # Full command
mx drake_2        # Quick alias
                  # Both play song matching "drake_2"

# Next song
next_song         # Full command
mn               # Quick alias

# Previous song
previous_song     # Full command
mp               # Quick alias

# Toggle play/pause
toggle_pause      # Full command
mt               # Quick alias

# Shuffle play
shuffle_play      # Full command
msh              # Quick alias
```

### Status and Information
```bash
# Show live status with progress bar
show_live_status  # Full command
ms               # Quick alias

# List all songs
list_songs       # Full command
ml               # Quick alias

# List all playlists
list_playlists   # Full command
mpl              # Quick alias
```

### Navigation
```bash
# Skip forward 30 seconds
seek_forward     # Full command
mf              # Quick alias

# Skip backward 30 seconds
seek_backward    # Full command
mb              # Quick alias

# Seek to specific time or relative position
seek 1:30       # Jump to 1 minute 30 seconds
seek +30        # Skip forward 30 seconds
seek -30        # Skip backward 30 seconds
```

### Playlist Management
```bash
# Switch playlist
switch_playlist rock  # Full command
msw rock            # Quick alias

# Create new playlist
create jazz         # Creates jazz.txt
```

### Volume Control
```bash
# Adjust volume
adjust_volume +10   # Full command
mv +10             # Quick alias
                   # Both increase volume by 10
```

## Using Playlists

### Playlist Format
Create playlist files (*.txt) with this format:
```
song_name | https://www.youtube.com/watch?v=...
another_song | https://www.youtube.com/watch?v=...
```
- One song per line
- The name of the song can be whatever string you like
- Use | to separate label from URL
- Labels can contain spaces
- URLs must be valid YouTube links

### Managing Multiple Playlists
- All playlists are .txt files in the same directory
- Switch between playlists using `msw` or `switch_playlist`
- Create new playlists using `create`
- Edit playlists with any text editor

## Live Status Display
Press `ms` (or `show_live_status`) to see:
```
Now Playing: Current Song Title
[1:23 / 3:45] [===============>                    ]
```
- Shows current track name
- Shows time position / total duration
- Shows visual progress bar
- Press 'q' to exit display

## Tips
- Partial matches work for song labels (`mx dra` finds "drake")
- Live status (`ms`) is great for longer tracks
- Run `help` to see all commands and examples

## Troubleshooting
- For socket errors, try `stop_playback` first
- If live display looks wrong, resize your terminal window

## Getting Help
Run `help` in the terminal to see:
- All available commands
- All aliases
- Usage examples
- Tips and tricks

## Legal Notice
This tool is provided for personal use only. Users are responsible for complying with YouTube's Terms of Service and all applicable copyright laws. The script facilitates playback of YouTube content through legal open-source tools (mpv and youtube-dl) but does not download, store, or redistribute any copyrighted content. Please respect content creators' rights and YouTube's terms of service when using this tool.
