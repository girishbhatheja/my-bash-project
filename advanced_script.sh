#!/bin/bash
#
# ========= My Advanced Bash Script Toolkit =========
#
# This script is a collection of advanced Bash functions
# to be used as a library or a starting point for complex projects.
#
# It includes functions for:
#   - Logging with timestamps
#   - Automatic cleanup
#   - Retrying failed commands
#   - Parsing config files
#   - Processing arrays
#   - And more!
#
# Author: [Your Name]
# Date: [Date]
#

# --- Script Safety Settings ---
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The exit code of a pipeline is the rightmost non-zero one,
#              or zero if all exit.
set -euo pipefail

# --- Global Variables ---
# Set default values. These can be overridden by command-line options.
DELAY=1
CONFIG_FILE="/tmp/script.conf"


#
# ======== 1. HELPER FUNCTIONS ========
#

##
# 💬 Prints a message with a timestamp.
# Usage: log_message "Your message here"
#
log_message() {
  # Format: [2025-11-09 11:30:00] Your message here
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
}

##
# 🧹 Cleans up temporary files.
# This function is called automatically when the script exits.
#
cleanup() {
  log_message "Cleaning up temporary files..."
  rm -rf /tmp/script_temp_*
  # Add any other cleanup commands here (e.g., remove file1, file2)
  rm -f file1 file2 file3
}

##
# 🛡️ Validates that the script received at least one argument.
# Usage: validate_params "$@"
#
validate_params() {
  # Check if the number of arguments ($#) is less than (-lt) 1.
  if [ $# -lt 1 ]; then
    # Print errors to 'stderr' (>&2)
    echo "ERROR: At least one parameter required" >&2
    echo "Usage: $0 <command> [options]" >&2
    exit 1
  fi
}

##
# ❓ Checks if a command exists on the system.
# Returns 0 (success) if found, 1 (failure) if not.
# Usage: if command_exists "git"; then ...
#
command_exists() {
  # 'command -v' checks if a command is executable in the $PATH.
  # '>/dev/null 2>&1' silences all output, we only care about the exit code.
  command -v "$1" >/dev/null 2>&1
}

##
# 🔁 Retries a command multiple times if it fails.
# Usage: retry_command <max_attempts> <delay_sec> <command_to_run...>
#
retry_command() {
  local max_attempts=$1
  local delay=$2
  # 'shift 2' discards the first two arguments (max_attempts and delay),
  # so that "$@" contains only the command to run.
  shift 2
  local count=0

  # 'until' loops *until* the command succeeds (returns 0).
  until "$@"; do
    count=$((count + 1))
    # Check if attempts are greater than or equal to (-ge) max.
    if [ $count -ge $max_attempts ]; then
      log_message "Command failed after $max_attempts attempts"
      return 1 # Return a failure code
    fi
    log_message "Attempt $count failed, retrying in $delay seconds..."
    sleep $delay
  done
  return 0 # Return a success code
}

##
# 🗃️ Reads a .conf file and loads settings as global variables.
# Config format: KEY=VALUE
# Usage: parse_config "/path/to/my.conf"
#
parse_config() {
  local config_file=$1
  
  # Check if config file does not (!) exist (-f).
  # Fixed syntax error: added space before ']'
  if [ ! -f "$config_file" ]; then
    log_message "Config file not found: $config_file"
    return 1
  fi

  # Read the file line by line.
  # 'IFS="="' sets the Internal Field Separator to '=', so 'read'
  # splits 'KEY=VALUE' into 'key' and 'value'.
  while IFS="=" read -r key value; do
    # Filter: Skip empty lines or lines starting with '#'
    # '-z "$key"' checks for empty key.
    # '[[ $key == \#* ]]' checks if key starts with '#'.
    [ -z "$key" ] || [[ $key == \#* ]] && continue

    # 'declare -g' creates a GLOBAL variable.
    # This makes $CONFIG_TIMEOUT available everywhere.
    declare -g "CONFIG_$key"="$value"
    log_message "Loaded config: $key=$value"
  done < "$config_file"
}

##
# 🗂️ Loops over an array and performs an operation.
# Usage: process_array <array_name> <operation>
#
process_array() {
  # 'local -n' creates a "nameref" (a pointer) to the original array.
  # This is the modern way to pass arrays to functions.
  local -n arr_ref=$1
  local operation=$2

  # '[@]' expands to all items in the array.
  # Quotes are vital to handle items with spaces.
  for item in "${arr_ref[@]}"; do
    log_message "Processing: $item with $operation"
    
    # 'case' is a clean way to handle multiple 'if' statements.
    case $operation in
      "validate")
        # Use retry_command to check if the file exists.
        # 'bash -c' is used to run the test command as a string.
        if retry_command 3 2 bash -c "[ -f \"$item\" ]"; then
          echo "  ✅ Valid: $item"
        else
          echo "  ❌ Invalid: $item"
        fi
        ;; # ';;' ends a case block
        
      "backup")
        if retry_command 3 2 cp "$item" "$item.bak"; then
          echo "  📦 Backed up: $item"
        else
          echo "  ⚠️ Failed to back up: $item"
        fi
        ;;
        
      *) # '*' is the default "catch-all" case.
        echo "  Unknown operation: $operation"
        ;;
    esac # 'esac' is 'case' backwards and ends the block.
  done
}

##
# 🐞 Prints useful debugging information.
#
debug_info() {
  log_message "=== Debug Information ==="
  log_message "Script: $0"       # Script name
  log_message "PID: $$"          # Process ID
  log_message "User: $(whoami)"  # Current user
  log_message "PWD: $PWD"        # Current directory
  log_message "Arguments: $*"    # All arguments passed
  log_message "========================"
}

##
# 📧 Validates an email address format using regex.
# Usage: validate_email "test@example.com"
#
validate_email() {
  local email=$1
  # '[[ $email =~ $regex ]]' is the Bash regex match operator.
  if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    log_message "Valid email: $email"
    return 0
  else
    log_message "Invalid email: $email"
    return 1
  fi
}

##
# ⏱️ Measures the execution time of a command.
# Usage: monitor_performance <command_to_run...>
#
monitor_performance() {
  local start_time=$(date +%s.%N)
  # "$@" runs all arguments as a command
  "$@"
  local exit_code=$? # Save the exit code
  local end_time=$(date +%s.%N)
  # 'bc -l' is a command-line calculator for floating-point math
  local duration=$(echo "$end_time - $start_time" | bc -l)
  log_message "Command: $* | Exit code: $exit_code | Duration: ${duration}s"
  return $exit_code
}

##
# 🚀 Processes items in parallel.
# Usage: parallel_process <max_jobs> <item1> <item2> ...
#
parallel_process() {
  local max_jobs=$1
  shift # Discard max_jobs, "$@" is now just the items
  local pids=() # Array to store background Process IDs

  for item in "$@"; do
    # Wait if we've hit the max job limit
    while [ ${#pids[@]} -ge $max_jobs ]; do
      for i in "${!pids[@]}"; do
        # 'kill -0' checks if a process is still running.
        if ! kill -0 ${pids[i]} 2>/dev/null; then
          wait ${pids[i]}   # Wait for the completed job
          unset pids[i]   # Remove it from the array
        fi
      done
      pids=("${pids[@]}") # Re-index the array
      sleep 0.1
    done

    # Run the task in a subshell (in the background)
    (
      log_message "Processing $item in background"
      sleep 2 # Simulate 2 seconds of work
      log_message "Completed $item"
    ) & # The '&' runs it in the background
    
    pids+=($!) # '$!' is the PID of the last backgrounded process
  done

  # Wait for all remaining jobs to finish
  for pid in "${pids[@]}"; do
    wait $pid
  done
}


#
# ======== 2. MAIN FUNCTION ========
#

##
# 🏁 This is the main entry point for the script.
# It parses options and runs the main command.
#
main() {
  # --- 1. Automatic Cleanup ---
  # 'trap' ensures the 'cleanup' function is called on
  # EXIT (normal exit), INT (Ctrl+C), or TERM (kill).
  trap cleanup EXIT INT TERM

  # --- 2. Option Parsing ---
  # 'getopts' parses "short options" like -h or -v.
  # "hvd:c:" means:
  #   -h, -v are simple flags
  #   -d, -c require an argument (e.g., -d 5)
  while getopts "hvd:c:" opt; do
    case $opt in
      h) # -h for Help
        echo "Usage: $0 <command> [-h] [-v] [-d delay] [-c config]"
        exit 0
        ;;
      v) # -v for Verbose (Debug Mode)
        # 'set -x' prints every command before it runs.
        set -x
        log_message "Verbose mode enabled."
        ;;
      d) # -d for Delay
        # '$OPTARG' holds the value passed to the option.
        DELAY=$OPTARG
        ;;
      c) # -c for Config File
        CONFIG_FILE=$OPTARG
        ;;
      ?) # '?' handles invalid options
        exit 1
        ;;
    esac
  done

  # --- 3. Shift Arguments ---
  # '$OPTIND' is the index of the next argument.
  # This 'shift' removes all options (like -v, -d 5)
  # from the argument list.
  # After this, '$1' is the *first non-option argument*.
  #
  # Fixed typos: OPTING -> OPTIND
  shift $((OPTIND - 1))

  # --- 4. Validate Input ---
  # Check if we have a main command (like 'test' or 'run').
  validate_params "$@"

  # --- 5. Main Logic (Command Router) ---
  # Save the main command (e.g., "test")
  local command=$1

  # Create the default config file for testing
  # This is a good place to put it, so it only
  # runs when the script runs.
  echo -e "DATABASE_HOST=localhost\nDATABASE_PORT=5432\nDEBUG_MODE=true" > /tmp/script.conf

  # Load the config file
  parse_config "$CONFIG_FILE"

  # Use 'case' to decide what to do based on the command.
  case $command in
    "test")
      log_message "=== Running All Tests ==="
      debug_info
      validate_email "test@example.com"
      validate_email "invalid-email"
      
      # Create dummy files for array test
      touch file1 file2
      files=("file1" "file2" "/tmp/missingfile")
      
      process_array files validate
      process_array files backup
      
      parallel_process 2 "task1" "task2" "task3" "task4"
      
      # Test the monitor function
      monitor_performance sleep 1
      
      log_message "=== All Tests Completed ==="
      ;;
      
    "run")
      log_message "Running in 'run' mode..."
      # '$2' is the command to run, e.g., 'ping'
      local cmd_to_run="${2-}" # Get 2nd arg, default to empty
      
      if [ -z "$cmd_to_run" ]; then
        log_message "ERROR: 'run' mode requires a command."
        echo "Usage: $0 run <command_to_run...>" >&2
        exit 1
      fi
      
      # Check if the command exists
      if ! command_exists "$cmd_to_run"; then
        log_message "Command '$cmd_to_run' not found"
        exit 1
      fi
      
      # Get all arguments *after* "run"
      shift 1 
      
      log_message "Executing command with 3 retries: $@"
      # Use the monitor to time the retry command
      monitor_performance retry_command 3 5 "$@"
      
      if [ $? -eq 0 ]; then
        log_message "Command finished successfully"
      else
        log_message "Command failed permanently."
      fi
      ;;
      
    *)
      log_message "Unknown command: $command"
      echo "Valid commands are: 'test', 'run'" >&2
      exit 1
      ;;
  esac
}

#
# ======== 3. SCRIPT EXECUTION ========
#
# This is the *only* command that runs in the global scope.
# It passes all script arguments ("$@") to the 'main' function.
#
main "$@"
