#!/bin/zsh
# this file converts a YouTube playlist (given as the playlist URL) to a txt file consisting of the URL's of the individual songs. it'll also automatically label the songs based on their titles.

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 [YouTube Playlist URL] [output_filename.txt]"
    echo "Example: $0 'https://youtube.com/playlist?list=...' rock.txt"
    exit 1
fi

playlist_url=$1
output_file=$2

if [[ ! $output_file =~ \.txt$ ]]; then
    output_file="${output_file}.txt"
fi

echo "Extracting playlist info to $output_file..."
echo "Preview of how labels will look:"
echo "--------------------------------"

youtube-dl --get-title --get-id "$playlist_url" | \
while read -r title; do
    read -r video_id 
    
    if [ -n "$title" ]; then
        label=$(echo "$title" | \
                tr -cd '[:alnum:] ' | \
                tr '[:upper:]' '[:lower:]' | \
                tr ' ' '_' | \
                sed 's/__*/_/g')
        
        echo "Original: $title"
        echo "Label   : $label"
        echo "---"
        
        echo "${label} | https://www.youtube.com/watch?v=${video_id}" >> "${output_file}.tmp"
    fi
done

echo -n "Would you like to proceed with creating the playlist file? (y/n) "
read answer

if [[ $answer == "y" ]]; then
    mv "${output_file}.tmp" "${output_file}"
    echo "Created playlist file: $output_file"
else
    rm "${output_file}.tmp"
    echo "Cancelled. No file was created."
fi
