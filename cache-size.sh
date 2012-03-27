# /bin/sh
if [ $# -lt 1 ] 
then
    echo "Usage: ./cache_size <cache_level_name>"
    echo "           cache_level_name being something like '"'L1'"', '"'L2'"', '"'L3'"'..."
    exit
fi

lstopo -v | grep "$1" | head -n 1 | tr -s ' ' | cut -d' ' -f 4 | tr -d '()'
