#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# name of suite (without .def!)
suiteName=$1        

# Function to print status with coloring
print_status() {
    local status="$1"
    case "$status" in
        "active"|"submitted"|"running")
            echo -e "${GREEN}${status}${NC}"
            ;;
        "queued"|"waiting"|"suspended")
            echo -e "${YELLOW}${status}${NC}"
            ;;
        "aborted"|"failed")
            echo -e "${RED}${status}${NC}"
            ;;
        "complete"|"completed")
            echo -e "${CYAN}${status}${NC}"
            ;;
        *)
            echo -e "${BLUE}${status}${NC}"
            ;;
    esac
}

# Function to get status icon based on status
get_status_icon() {
    local status="$1"
    case "$status" in
        "active"|"submitted"|"complete")
            echo -e "${GREEN}✓${NC}"
            ;;
        "queued"|"waiting"|"suspended")
            echo -e "${YELLOW}⏸${NC}"
            ;;
        "aborted"|"failed")
            echo -e "${RED}✗${NC}"
            ;;
        *)
            echo -e "${BLUE}⦿${NC}"
            ;;
    esac
}

# function to parse lines obtained from command:
#       ecflow_client --get_state=/nameOfSuite.
#
# The line must contain the strings: "suite ","task ","family "
#
#        [[ $line =~ (suite |task |family ) ]] must be true.        
#             
parse_string() {
    local input="$1"
    local return_var="$2"
    
    # Count leading spaces before first word
    local leading_spaces=$(echo "$input" | sed -E 's/^( *).*$/\1/' | wc -c)
    # Adjust count (wc -c counts the newline character too)
    leading_spaces=$((leading_spaces - 1))
    
    # Extract first word (task or family)
    local first_word=$(echo "$input" | grep -o "^[[:space:]]*\(task\|family\|suite\)" | tr -d ' ')
    
    # Extract name (the word after task or family)
    local name=$(echo "$input" | sed -E 's/^[[:space:]]*(task|family|suite)[[:space:]]+([^[:space:]#]+).*/\2/')
    
    # Extract state (complete, aborted, running, queued)
    local state=$(echo "$input" | grep -o "state:\(complete\|aborted\|running\|queued\|submitted\|active\)" | cut -d':' -f2)
    
    # Return values using variable references
    eval "${return_var}_SPACES=$leading_spaces"
    eval "${return_var}_FIRST=$first_word"
    eval "${return_var}_NAME=$name"
    eval "${return_var}_STATE=$state"
}



temporaryFile=`mktemp ./suiteTemp_XXXXX`
#echo "creating: ${temporaryFile}"
touch ${temporaryFile}

if [[ $# -eq 0 ]]; then # suite name not specified, consider the only one loaded 
    ecflow_client --port=${ECF_PORT} --host=${ECF_HOST} --get_state > ${temporaryFile}
else
    ecflow_client --port=${ECF_PORT} --host=${ECF_HOST} --get_state=${suiteName} > ${temporaryFile}
fi 

if [[ "$?" -ne "0" ]]; then 
    echo "Error with fetching the status of suite: ${suiteName}"
    echo "Check if the suite name is correct or that you have any suite "
    echo "loaded"
    exit 1 
fi

while IFS= read -r line
do

    if [[ $line =~ (suite |task |family ) ]]; then  # select line if corresponds to a (suite/family or task)

        parse_string "$line" "RESULT1"              # parse the line and store result in RESULT1 variable

        depth=$RESULT1_SPACES
        depth=$((depth * 2 ))   # this makes more readable

        # Get the node name (last part of path)
        node_name=$RESULT1_NAME

        status=$RESULT1_STATE

        node_type=$RESULT1_FIRST                    # suite line doest have indentation space
        if [[ $node_type == "suite" ]]; then
            node_type_color="${MAGENTA}SUITE${NC}"
            echo -e "${BOLD}${node_name}${NC} (${node_type_color}) - $(print_status "$status") $(get_status_icon "$status")"
        else
            if [[ $node_type == "family" ]]; then 
                node_type_color="${CYAN}FAMILY${NC}"
            else 
                node_type_color="${BLUE}TASK${NC}"
            fi
            prefix=$(printf "%$((depth-1))s" | tr ' ' '│')
            echo -e "${prefix}├─ ${node_name} (${node_type_color}) - $(print_status "$status") $(get_status_icon "$status")"
        fi

    fi

done < "${temporaryFile}"


rm $temporaryFile



#useful command
#cat suiteTemp_KP1RD | grep --color=always -E "suite | task | family | state| flag| rt| try" | grep -v server


