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

# Function to check if file should be included
should_include_file() {
    local file="$1"

    # Skip binary files, hidden files, and unnecessary directories
    if [[ -d "$file" ]] || \
       [[ "$file" == *"node_modules"* ]] || \
       [[ "$file" == *"dist"* ]] || \
       [[ "$file" == *".git"* ]] || \
       [[ "$file" == *".lock"* ]] || \
       [[ "$file" == *".ico"* ]] || \
       [[ "$file" == *".svg"* ]] || \
       [[ "$file" == *".png"* ]] || \
       [[ "$file" == *".jpg"* ]] || \
       [[ "$file" == *".webp"* ]] || \
       [[ "$file" == *".json"* ]] || \
       [[ "$file" == *".md"* ]] || \
       [[ "$(basename "$file")" == .* ]]; then
        return 1
    fi

    # Check file size
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

# Get total number of files first
total_files=$(find "$PROJECT_ROOT/src" -type f ! -path "*/node_modules/*" ! -path "*/dist/*" | wc -l)
current_file=0

# Walk through project directory
echo "Starting file processing from $PROJECT_ROOT/src..."
echo "Including: Vue source files, excluding node_modules and dist."
while IFS= read -r file; do
    ((current_file++))
    printf "\rProcessing files: [%d/%d]" $current_file $total_files
    process_file "$file"
done < <(find "$PROJECT_ROOT/src" -type f ! -path "*/node_modules/*" ! -path "*/dist/*")

# Clear the progress bar line and show completion
printf "\rFile processing completed! Processed %d files.                        \n" $total_files

echo "Prompt has been generated in $OUTPUT_FILE"
