#!/bin/bash


#################################################################
# VULNER - Automated Network Scanning & Vulnerability Mapping   #
#                                                               #
# Receives a local /24 network range and an output directory,   #
# discovers active hosts, and performs controlled security      #
# checks (Basic or Full mode) against every detected target.    #
# Saves structured results and can export them to a Zip file.   #
#                                                               #
# FOR AUTHORIZED LAB / EDUCATIONAL USE ONLY.                    #
#################################################################


# creating empty arrays for detected targets and local usernames #
targets_array=()
usernames=()

# global variables used during the program #
network_range=""
output_directory=""
results_file=""
scan_mode=""
password_file=""
built_in_password_file="/tmp/password.lst"
zip_file=""


# printing the main project banner #
function print_banner(){
    echo "---------------------------------------"
    echo " PENETRATION TESTING | PROJECT: VULNER"
    echo "---------------------------------------"
    echo ""
    sleep 1
}



# checking if the script runs with root permissions #
function check_root(){
    echo "Checking script permissions..."
    sleep 1

    # some Nmap scans require root permissions #
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR - please run this script with sudo/root permissions."
        echo "Example: sudo bash vulner.sh"
        exit 1
    fi

    echo "Root permissions - VALID"
    echo ""
}



# checking if the required tools are installed #
function check_dependencies(){
    echo "Verifying that required tools are installed..."
    sleep 1

    # Nmap is used for host discovery, port scans and service detection #
    # Hydra is used for weak credentials checks #
    # Zip is used for saving the results into a Zip file #
    for tool in nmap hydra zip; do

        if command -v "$tool" &> /dev/null; then
            echo "[+] Found $tool"
        else
            read -p "$tool is not installed. Would you like to install it now? (y/n): " install_choice

            if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                echo "Installing $tool..."

                apt update
                apt install -y "$tool"

                # checking if the tool was installed successfully #
                if command -v "$tool" &> /dev/null; then
                    echo "[+] $tool was installed successfully."
                else
                    echo "ERROR - $tool installation failed."
                    exit 1
                fi
            else
                echo "Exiting program. $tool is required."
                exit 1
            fi
        fi
    done

    echo ""
}



# checking if Searchsploit is installed when Full scan mode is selected #
function check_searchsploit(){

    if command -v searchsploit &> /dev/null; then
        echo "[+] Found searchsploit"
    else
        read -p "searchsploit is not installed. Would you like to install it now? (y/n): " install_choice

        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            echo "Installing exploitdb..."

            apt update
            apt install -y exploitdb

            # checking if Searchsploit was installed successfully #
            if command -v searchsploit &> /dev/null; then
                echo "[+] Searchsploit was installed successfully."
            else
                echo "ERROR - Searchsploit installation failed."
                exit 1
            fi
        else
            echo "Exiting program. Searchsploit is required for Full scan mode."
            exit 1
        fi
    fi

    echo ""
}


# checks if value is a number and greater/equal to 0 #
function is_number(){
    [ -n "$1" ] && [ "$1" -ge 0 ] 2>/dev/null
}


# checking if the entered IPv4 address is valid #
function validate_ip_address(){
    local ip_address="$1"
    local first_part
    local second_part
    local third_part
    local fourth_part

    # separating the IP address into four parts #
    IFS='.' read -r first_part second_part third_part fourth_part <<< "$ip_address"

    # checking that all four parts exist #
    if [ -z "$first_part" ] || [ -z "$second_part" ] || [ -z "$third_part" ] || [ -z "$fourth_part" ]; then
        return 1
    fi

    # checking every part of the IP address #
    for number in "$first_part" "$second_part" "$third_part" "$fourth_part"; do

        if ! is_number "$number"; then
            return 1
        fi

        if [ "$number" -lt 0 ] || [ "$number" -gt 255 ]; then
            return 1
        fi
    done

    return 0
}


# getting a network range from the user #
function get_network_range(){
    echo "Finding local IP address..."
    sleep 1

    # getting the local IP address of this machine #
    local_ip=$(hostname -I | awk '{print $1}')

    if [ -z "$local_ip" ]; then
        echo "ERROR - could not find a local IP address."
        echo "Please check the local network connection."
        exit 1
    fi

    # getting the first three parts of the local IP address #
    local_network=$(echo "$local_ip" | cut -d "." -f 1-3)

    echo "Local IP address - $local_ip"
    echo "Local network - $local_network.0/24"
    echo ""

    while true; do
        read -p "Enter a network range to scan (example: $local_network.0/24): " entered_network

        # removing spaces from the user input #
        entered_network=$(echo "$entered_network" | tr -d '[:space:]')

        # separating the IP address and the CIDR range #
        IFS='/' read -r network_ip cidr_range <<< "$entered_network"

        # checking if the IP address is valid #
        if ! validate_ip_address "$network_ip"; then
            echo "ERROR - invalid IPv4 address."
            echo ""
            continue
        fi

        # checking that the CIDR is 24 #
        if [ "$cidr_range" != "24" ]; then
            echo "ERROR - please enter a /24 local network."
            echo ""
            continue
        fi

        # getting the first three parts of the entered network #
        entered_network_parts=$(echo "$network_ip" | cut -d "." -f 1-3)

        # checking that the entered network matches the local network #
        if [ "$entered_network_parts" != "$local_network" ]; then
			echo "ERROR - the entered network does not match the local network."
			echo "Please enter a valid local /24 network range."
			echo ""
            continue
        fi

        # saving the address as a correct /24 network range #
        network_range="$entered_network_parts.0/24"
        break
    done

    echo ""
    echo "Selected network range - $network_range"
    echo ""
}



# getting a name for the output directory #
function get_output_directory(){

    while true; do
        read -p "Enter a name for the output directory: " output_directory

        echo "Validating output directory name..."
        sleep 1

        # removing spaces from the input #
        output_directory=$(echo "$output_directory" | tr -d '[:space:]')

        # checking if the directory name is empty #
        if [ -z "$output_directory" ]; then
            echo "Output directory name - INVALID"
            echo "Please enter a directory name."
            echo ""
            continue
        fi

        # allowing only letters, numbers, underscore and hyphen #
        case "$output_directory" in
            *[!a-zA-Z0-9_-]*)
                echo "Output directory name - INVALID"
                echo "Use only letters, numbers, underscore or hyphen."
                echo ""
                continue
                ;;
        esac

        results_file="$output_directory/results.txt"

        # checking if a file with the same name already exists #
        if [ -e "$output_directory" ] && [ ! -d "$output_directory" ]; then
            echo "ERROR - a file with this name already exists."
            echo "Please choose another directory name."
            echo ""
            continue
        fi

        # checking if the output directory already exists #
        if [ -d "$output_directory" ]; then
            echo "Output directory already exists."
            echo "1) Overwrite the existing results file"
            echo "2) Enter another directory name"
            echo ""

            read -p "Choose option 1-2: " directory_choice

            if [ "$directory_choice" = "1" ]; then
                > "$results_file"

                echo ""
                echo "Existing results file was overwritten."
                echo "Results will be saved in - $results_file"
                echo ""
                break

            elif [ "$directory_choice" = "2" ]; then
                echo ""
                continue

            else
                echo "ERROR - invalid choice."
                echo "Please choose option 1 or 2."
                echo ""
                continue
            fi
        fi

        # creating the output directory #
        mkdir "$output_directory"

        # checking if the directory was created successfully #
        if [ ! -d "$output_directory" ]; then
            echo "ERROR - could not create the output directory."
            exit 1
        fi

        # creating the results file inside the output directory #
        touch "$results_file"

        if [ ! -f "$results_file" ]; then
            echo "ERROR - could not create the results file."
            exit 1
        fi

        echo "Output directory - VALID"
        echo "Results will be saved in - $results_file"
        echo ""
        break
    done
}


# allowing the user to choose Basic or Full scan mode #
function choose_scan_mode(){
    echo "Choose scan mode:"
    echo "---------------------------------------"
    echo "1) Basic - TCP, UDP, service versions and weak credentials."
    echo "2) Full - Basic scan, NSE and Searchsploit vulnerability mapping."
    echo ""

    read -p "Choose scan mode 1-2: " mode_choice
    mode_choice=$(echo "$mode_choice" | tr -d '[:space:]')

    case "$mode_choice" in
        1)
            scan_mode="Basic"
            ;;
        2)
            scan_mode="Full"
            ;;
        *)
            echo "ERROR - invalid scan mode choice."
            echo ""
            choose_scan_mode
            return
            ;;
    esac

    echo "Selected scan mode - $scan_mode"
    echo ""
}



# creating the built-in password.lst file #
function create_built_in_password_list(){
    rm -f "$built_in_password_file"
    cat > "$built_in_password_file" <<PASSWORDS
1234
123456
admin
password
12345678
qwerty
123123
111111
root
toor
Pass@123
admin123
user
PASSWORDS
    password_file="$built_in_password_file"
}



# allowing the user to choose the built-in or a personal password list #
function choose_password_list(){
    echo "Choose password list:"
    echo "---------------------------------------"
    echo "1) Use the built-in password.lst file."
    echo "2) Use my own password list file."
    echo ""

    read -p "Choose password list 1-2: " password_choice
    password_choice=$(echo "$password_choice" | tr -d '[:space:]')

    case "$password_choice" in
        1)
            create_built_in_password_list
            echo "Built-in password.lst file selected."
            ;;
        2)
            read -p "Enter the full path to your password list file: " custom_password_file

            # checking that the selected file exists, can be read and is not empty #
            if [ -f "$custom_password_file" ] && [ -r "$custom_password_file" ] && [ -s "$custom_password_file" ]; then
                password_file="$custom_password_file"
                echo "Personal password list selected."
            else
                echo "ERROR - the selected password list is not valid."
                echo ""
                choose_password_list
                return
            fi
            ;;
        *)
            echo "ERROR - invalid password list choice."
            echo ""
            choose_password_list
            return
            ;;
    esac

    echo ""
}



# collecting local Linux usernames from the operating system #
function collect_local_usernames(){
    echo "Collecting local usernames from the operating system..."
    sleep 1

    usernames=("root")

    # reading the /etc/passwd file line by line #
    while IFS=: read -r username password user_id group_id description home_directory user_shell; do

        # regular users usually have ID 1000 or higher #
        if [ "$user_id" -ge 1000 ] 2>/dev/null; then

            # skipping users that cannot login #
            if [[ "$user_shell" != *"nologin"* && "$user_shell" != *"false"* ]]; then

                # preventing root from being added twice #
                if [ "$username" != "root" ]; then
                    usernames+=("$username")
                fi
            fi
        fi

    done < /etc/passwd

    echo "Usernames selected for weak credentials checks:"
    echo "---------------------------------------"

    for username in "${usernames[@]}"; do
        echo "[-] $username"
    done

    echo ""
}



# preparing the beginning of the results file #
function prepare_results_file(){
    {
        echo "======================================="
        echo "VULNER - PENETRATION TESTING REPORT"
        echo "======================================="
        echo "Date: $(date)"
        echo "Network: $network_range"
        echo "Scan Mode: $scan_mode"
        echo "Output Directory: $output_directory"
        echo "======================================="
        echo ""
    } >> "$results_file"
}



# scanning the selected network and saving all active IP addresses #
function discover_active_hosts(){
    echo "Scanning the network for active IP addresses..."
    echo "Network range to scan - $network_range"
    sleep 1

    scan_result=$(nmap -sn "$network_range")

    # taking the last word from every Nmap scan report line #
    detected_hosts=$(echo "$scan_result" | grep "Nmap scan report for" | awk '{print $NF}' | tr -d '()')

    # checking if no active IP addresses were found #
    if [ -z "$detected_hosts" ]; then
        echo ""
        echo "ERROR - No active IP addresses were found in the selected network."
        echo ""
        echo "Please verify:"
        echo "- The network range is correct."
        echo "- The machine is connected to the local network."
        echo "- The active network interface is enabled."
        echo ""
        echo "Program terminated."

        rm -f "$built_in_password_file"
        exit 1
    fi

    # saving the detected IP addresses into an array #
    targets_array=($detected_hosts)

    echo "Network scan completed."
    echo "${#targets_array[@]} active IP addresses were found."
    echo ""

    # displaying all detected IP addresses in the terminal #
    echo "Active IP addresses:"
    echo "---------------------------------------"

    for target_ip in "${targets_array[@]}"; do
        echo "$target_ip"
    done

    echo ""

    # saving all detected IP addresses into the results file #
    echo "ACTIVE IP ADDRESSES" >> "$results_file"
    echo "---------------------------------------" >> "$results_file"

    for target_ip in "${targets_array[@]}"; do
        echo "$target_ip" >> "$results_file"
    done

    echo "" >> "$results_file"
}


# running a TCP scan with service version detection #
function run_tcp_scan(){
    local target_ip="$1"

    echo "[Stage 1] Running TCP scan on: $target_ip"

    tcp_output=$(nmap -Pn -sS -sV --top-ports 1000 "$target_ip" 2>&1)

    {
        echo "TCP SCAN RESULTS"
        echo "---------------------------------------"
        echo "$tcp_output"
        echo ""
    } >> "$results_file"

    echo "TCP scan completed for $target_ip."
    echo ""
}



# running a UDP scan with service version detection #
function run_udp_scan(){
    local target_ip="$1"

    echo "[Stage 2] Running UDP scan on: $target_ip"

    udp_output=$(nmap -n -Pn -sU -sV --version-light --top-ports 5 -T4 --max-retries 1 --host-timeout 30s "$target_ip" 2>&1)

    echo "UDP SCAN RESULTS" >> "$results_file"
    echo "---------------------------------------" >> "$results_file"
    echo "$udp_output" >> "$results_file"
    echo "" >> "$results_file"

    echo "UDP scan completed for $target_ip."
    echo ""
}



# checking one login service for weak credentials #
function test_login_service(){
    local target_ip="$1"
    local service_name="$2"
    local port_number="$3"
    local hydra_service="$4"

    echo "Checking $service_name weak credentials on: $target_ip"

    {
        echo "Service: $service_name"
        echo "Port: $port_number"
        echo "---------------------------------------"
    } >> "$results_file"

    # checking every local username separately #
    for username in "${usernames[@]}"; do
        echo "Checking username: $username"

        hydra_output=$(hydra -l "$username" -P "$password_file" -s "$port_number" "$target_ip" "$hydra_service" -t 1 -f 2>&1)

        # looking for a successful Hydra line #
        found_line=$(echo "$hydra_output" | grep "login:" | grep "password:" | head -n 1)

        if [ -n "$found_line" ]; then
            found_password=$(echo "$found_line" | awk -F "password: " '{print $2}' | awk '{print $1}')

            {
                echo "Username: $username"
                echo "Password: $found_password"
                echo "Status: FOUND"
                echo ""
            } >> "$results_file"

        # checking if Hydra returned an error #
        elif echo "$hydra_output" | grep -qiE "error|failed|refused|timed out|not supported|unknown service"; then
            {
                echo "Username: $username"
                echo "Password: Test was not completed"
                echo "Status: TEST ERROR"
                echo "Hydra Message:"
                echo "$hydra_output"
                echo ""
            } >> "$results_file"

        else
            {
                echo "Username: $username"
                echo "Password: Not found"
                echo "Status: NOT FOUND"
                echo ""
            } >> "$results_file"
        fi
    done

    echo "$service_name weak credentials check completed for $target_ip."
    echo ""
}



# checking SSH, FTP, TELNET and RDP login services #
function check_weak_credentials(){
    local target_ip="$1"

    echo "[Stage 3] Checking login services on: $target_ip"

    {
        echo "WEAK CREDENTIALS RESULTS"
        echo "---------------------------------------"
    } >> "$results_file"

    # checking if SSH port 22 is open #
    if echo "$tcp_output" | grep -q "22/tcp[[:space:]]*open"; then
        test_login_service "$target_ip" "SSH" "22" "ssh"
    else
        echo "SSH port 22 is closed - credential check skipped." >> "$results_file"
        echo "" >> "$results_file"
    fi

    # checking if FTP port 21 is open #
    if echo "$tcp_output" | grep -q "21/tcp[[:space:]]*open"; then
        test_login_service "$target_ip" "FTP" "21" "ftp"
    else
        echo "FTP port 21 is closed - credential check skipped." >> "$results_file"
        echo "" >> "$results_file"
    fi

    # checking if TELNET port 23 is open #
    if echo "$tcp_output" | grep -q "23/tcp[[:space:]]*open"; then
        test_login_service "$target_ip" "TELNET" "23" "telnet"
    else
        echo "TELNET port 23 is closed - credential check skipped." >> "$results_file"
        echo "" >> "$results_file"
    fi

    # checking if RDP port 3389 is open #
    if echo "$tcp_output" | grep -q "3389/tcp[[:space:]]*open"; then

        # checking if the installed Hydra version supports RDP #
        if hydra -h 2>&1 | grep -qw "rdp"; then
            test_login_service "$target_ip" "RDP" "3389" "rdp"
        else
            {
                echo "RDP port 3389 is open."
                echo "RDP credential check was skipped."
                echo "The installed Hydra version does not support the RDP module."
                echo ""
            } >> "$results_file"
        fi
    else
        echo "RDP port 3389 is closed - credential check skipped." >> "$results_file"
        echo "" >> "$results_file"
    fi

    echo "Login services check completed for $target_ip."
    echo ""
}



# running Nmap Scripting Engine vulnerability checks #
function run_nse_scan(){
    local target_ip="$1"

    echo "[Stage 4] Running NSE vulnerability scan on: $target_ip"

    nse_output=$(nmap -Pn -sV --script vuln --host-timeout 5m "$target_ip" 2>&1)

    {
        echo "NSE VULNERABILITY RESULTS"
        echo "---------------------------------------"
        echo "$nse_output"
        echo ""
    } >> "$results_file"

    echo "NSE vulnerability scan completed for $target_ip."
    echo ""
}



# searching service names and versions with Searchsploit #
function run_searchsploit(){
    local target_ip="$1"

    echo "[Stage 5] Running Searchsploit analysis on: $target_ip"

    {
        echo "SEARCHSPLOIT RESULTS"
        echo "---------------------------------------"
    } >> "$results_file"

    # reading only open TCP service lines from the current TCP scan #
    service_lines=$(echo "$tcp_output" | grep "/tcp" | grep "open")

    if [ -z "$service_lines" ]; then
        echo "No open TCP services were found for Searchsploit analysis." >> "$results_file"
        echo "" >> "$results_file"
        return
    fi

    while IFS= read -r service_line; do
        service_name=$(echo "$service_line" | awk '{print $3}')
        service_version=$(echo "$service_line" | cut -d ' ' -f 4-)

        # using the service name and version as the Searchsploit search value #
        search_value="$service_name $service_version"

        echo "Searching for: $search_value" >> "$results_file"
        searchsploit "$search_value" >> "$results_file" 2>&1
        echo "" >> "$results_file"

    done <<< "$service_lines"

    echo "" >> "$results_file"
    echo "Searchsploit analysis completed for $target_ip."
    echo ""
}



# scanning one detected IP address and saving its own results section #
function scan_target(){
    local target_ip="$1"

    {
        echo "======================================="
        echo "TARGET IP: $target_ip"
        echo "======================================="
        echo ""
    } >> "$results_file"

    run_tcp_scan "$target_ip"
    run_udp_scan "$target_ip"
    check_weak_credentials "$target_ip"

    if [ "$scan_mode" = "Full" ]; then
        run_nse_scan "$target_ip"
        run_searchsploit "$target_ip"
    else
        {
            echo "VULNERABILITY MAPPING"
            echo "---------------------------------------"
            echo "Not executed - Basic scan mode was selected."
            echo ""
        } >> "$results_file"
    fi
}



# scanning every active IP address found in the selected network #
function scan_all_targets(){
    for target_ip in "${targets_array[@]}"; do
        echo "======================================="
        echo "Starting security checks for: $target_ip"
        echo "======================================="
        echo ""

        scan_target "$target_ip"
    done
}



# displaying the final information found during the scan #
function display_final_report(){
    {
        echo ""
        echo "FINAL SUMMARY"
        echo "---------------------------------------"
        echo "Network Scanned: $network_range"
        echo "Scan Mode: $scan_mode"
        echo "Active IP Addresses Found: ${#targets_array[@]}"
        echo "Results File: $results_file"
        echo ""
        echo "VULNER Assessment Complete"
    } >> "$results_file"

    echo ""
    cat "$results_file"
}



# allowing the user to search inside the results file #
function search_inside_results(){
    while true; do
        echo ""
        read -p "Would you like to search inside the results? (y/n): " search_choice

        if [[ "$search_choice" == "n" || "$search_choice" == "N" ]]; then
            break
        fi

        if [[ "$search_choice" != "y" && "$search_choice" != "Y" ]]; then
            echo "ERROR - enter y or n."
            continue
        fi

        read -p "Enter a word or sentence to search: " search_value

        # checking that the search value is not empty #
        if [ -z "$search_value" ]; then
            echo "ERROR - search value cannot be empty."
            continue
        fi

        found_result=false
        current_target="General Results"

        echo ""
        echo "SEARCH RESULTS"
        echo "---------------------------------------"

        # reading the results file line by line #
        while IFS= read -r line; do

            # saving the current target IP section #
            if [[ "$line" == "TARGET IP:"* ]]; then
                current_target=$(echo "$line" | cut -d ":" -f 2 | tr -d '[:space:]')
            fi

            # checking if the current line contains the search value #
            if echo "$line" | grep -qi -- "$search_value"; then
                echo "Target IP: $current_target"
                echo "Result: $line"
                echo ""
                found_result=true
            fi

        done < "$results_file"

        if [ "$found_result" = true ]; then
            echo "Search completed."
        else
            echo "No matching results were found."
        fi
    done
}



# allowing the user to save all results into a Zip file #
function create_results_zip(){
    echo ""
    read -p "Would you like to save all results into a Zip file? (y/n): " zip_choice

    if [[ "$zip_choice" == "y" || "$zip_choice" == "Y" ]]; then
        zip_file="${output_directory}.zip"

        rm -f "$zip_file"
        zip -r "$zip_file" "$output_directory" > /dev/null

        if [ -f "$zip_file" ]; then
            echo "Zip file created successfully - $zip_file"
        else
            echo "ERROR - could not create the Zip file."
        fi

    elif [[ "$zip_choice" == "n" || "$zip_choice" == "N" ]]; then
        echo "Zip file was not created."
    else
        echo "ERROR - enter y or n."
        create_results_zip
    fi
}



# deleting temporary files created by the script #
function cleanup(){
    rm -f "$built_in_password_file"
}



# main function that controls the full project flow #
function main(){

    # deleting temporary files whenever the program ends #
    trap cleanup EXIT

    print_banner
    check_root
    check_dependencies
    get_network_range
    get_output_directory
    choose_scan_mode

    # Searchsploit is required only for Full scan mode #
    if [ "$scan_mode" = "Full" ]; then
        check_searchsploit
    fi

    choose_password_list
    collect_local_usernames
    prepare_results_file
    discover_active_hosts
    scan_all_targets
    display_final_report
    search_inside_results
    create_results_zip
}


main
