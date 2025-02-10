#!/bin/bash

# Show usage information
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generates a prompt file by combining:
1. Context from context.txt
2. Project directory structure
3. Contents of all relevant source files

The generated prompt will be saved as 'generated_prompt.txt'

Options:
    -h, --help              Show this help message
    -o, --output FILE       Specify output file (default: generated_prompt.txt)
    -c, --context FILE      Specify context file (default: context.txt)
    --max-file-size SIZE   Skip files larger than SIZE in bytes (default: 1000000)

Examples:
    $(basename "$0")                    # Generate using defaults
    $(basename "$0") -o custom.txt      # Save output to custom.txt
    $(basename "$0") -c my_context.txt  # Use different context file
EOF
}

# Built-in tree function to replace external tree command
print_tree() {
    local dir="${1:-.}"
    local prefix="${2}"
    local excluded="${3:-node_modules|_build|deps|.git|*.beam|*.ez|ai}"
    
    # Get all items in directory, excluding hidden files and excluded patterns
    local items=($(ls -A "$dir" 2>/dev/null | grep -Ev "$excluded" | sort))
    local total=${#items[@]}
    
    local i
    for ((i=0; i<$total; i++)); do
        local item="${items[$i]}"
        local path="$dir/$item"
        local is_last=$((i == total-1))
        
        # Print item with appropriate prefix
        if [ $is_last -eq 1 ]; then
            echo "${prefix}└── $item"
            new_prefix="${prefix}    "
        else
            echo "${prefix}├── $item"
            new_prefix="${prefix}│   "
        fi
        
        # Recursively process directories
        if [ -d "$path" ]; then
            print_tree "$path" "$new_prefix" "$excluded"
        fi
    done
}

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -W)"
CONTEXT_FILE="$SCRIPT_DIR/context.txt"
OUTPUT_FILE="$SCRIPT_DIR/generated_prompt.txt"
MAX_FILE_SIZE=1000000

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--context)
            CONTEXT_FILE="$2"
            shift 2
            ;;
        --max-file-size)
            MAX_FILE_SIZE="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if context file exists
if [ ! -f "$CONTEXT_FILE" ]; then
    echo "Error: Context file not found: $CONTEXT_FILE"
    echo "Create the file or specify a different one with -c option"
    exit 1
fi

# Print initial directory information
echo "Script running from: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo

# Create or clear the output file
cp "$CONTEXT_FILE" "$OUTPUT_FILE"

# Function to check if path should be included
should_process_path() {
    local path="$1"
    local rel_path="${path#$PROJECT_ROOT/}"
    
    # Only include mix.exs, lib/ and priv/ paths
    if [[ "$rel_path" == "mix.exs" ]] || \
       [[ "$rel_path" == lib/* ]] || \
       [[ "$rel_path" == priv/* ]]; then
        return 0
    fi
    return 1
}
should_include_file() {
    local file="$1"
    
    # Skip binary files, hidden files, and specific directories
    if [[ -d "$file" ]] || \
       [[ "$file" == *"node_modules"* ]] || \
       [[ "$file" == *"_build"* ]] || \
       [[ "$file" == *"deps"* ]] || \
       [[ "$file" == *".git"* ]] || \
       [[ "$file" == *".beam" ]] || \
       [[ "$file" == *".ez" ]] || \
       [[ "$file" == *"ai"* ]] || \
       [[ "$file" == *".ico"* ]] || \
       [[ "$file" == *".svg"* ]] || \
       [[ "$file" == *".lock"* ]] || \
       [[ "$file" == *".heex"* ]] || \
       [[ "$(basename "$file")" == .* ]]; then
        return 1
    fi
    
    # Check file size (Windows Git Bash compatible)
    local size=$(stat --format=%s "$file" 2>/dev/null)
    if [ $? -eq 0 ] && [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        echo "Skipping large file: $file ($size bytes)"
        return 1
    fi
    
    # Check if file is binary
    if file "$file" | grep -q "binary"; then
        return 1
    fi
    
    return 0
}

# Function to process each file
process_file() {
    local file="$1"
    local rel_path="${file#$PROJECT_ROOT/}"
    
    if should_include_file "$file"; then
        echo -e "\n=== File: $rel_path ===\n" >> "$OUTPUT_FILE"
        cat "$file" >> "$OUTPUT_FILE"
    fi
}

# Simple progress counter
print_progress() {
    local current=$1
    local total=$2
    printf "\rProcessing files: [%d/%d]" $current $total
}


# Get total number of files first (only from relevant paths)
total_files=$(find "$PROJECT_ROOT" \( -name "mix.exs" -o -path "*/lib/*" -o -path "*/priv/*" \) -type f ! -path "*/deps/*" ! -path "*/_build/*" | wc -l)
current_file=0

# Walk through project directory with progress bar
echo "Starting file processing from $(dirname "$PROJECT_ROOT")..."
echo "Including: mix.exs, lib/, and priv/ directories"
while IFS= read -r file; do
    if should_process_path "$file"; then
        ((current_file++))
        print_progress $current_file $total_files
        process_file "$file"
    fi
done < <(find "$PROJECT_ROOT" \( -name "mix.exs" -o -path "*/lib/*" -o -path "*/priv/*" \) -type f ! -path "*/deps/*" ! -path "*/_build/*")

# Clear the progress bar line and show completion
printf "\rFile processing completed! Processed %d files.                        \n" $total_files

echo "Prompt has been generated in $OUTPUT_FILE"

