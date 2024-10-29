#!/bin/bash

# Settings
recipient_email="change@me"  # DNS server admins' email addresses
subject="AuditDomainHazardDNS results"
charset="utf-8"
hazard_zones_file=$(mktemp)
results_file=$(mktemp)
problem_domains_file=$(mktemp)
dns_servers=("1.1.1.1" "8.8.8.8")  # List of DNS servers to test

# Test mode flag
test_mode=false

# Check for the test mode argument
if [[ "$1" == "--test" ]]; then
    test_mode=true
fi

# Function to send emails
send_email() {
    local message="$1"
    {
        echo "To: $recipient_email"
        echo "Subject: $subject"
        echo "Content-Type: text/plain; charset=$charset"
        echo ""
        echo -e "$message"
    } | ssmtp "$recipient_email"
}

# Function to fetch data with speed
fetch_data() {
    echo "Fetching data from API..."
    local start_time=$(date +%s)

    # Fetching the file
    curl -k --silent --show-error -H "Accept: application/xml" -H "Content-Type: application/xml" \
        -X GET https://hazard.mf.gov.pl/api/Register -o "$hazard_zones_file"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Calculate download speed only if duration is greater than zero
    if [ "$duration" -gt 0 ]; then
        local file_size=$(stat -c%s "$hazard_zones_file")
        local download_speed=$(echo "scale=2; $file_size / $duration / 1024" | bc)  # Speed in KB/s
        echo "Fetching completed. Speed: ${download_speed} KB/s"
    else
        echo "Fetching completed, but duration is zero."
    fi

    echo "Download time: ${duration} seconds"

    if [ $? -ne 0 ]; then
        echo "Error fetching data. Check your internet connection or API address."
        exit 1
    elif [ ! -s "$hazard_zones_file" ]; then
        echo "Received empty file. Check the API response."
        exit 1
    fi
}

# Function to analyze results with speed
analyze_results() {
    echo "Analyzing results..."
    local total_domains=$(grep -c "<AdresDomeny>" "$hazard_zones_file")
    local processed_domains=0
    local start_time=$(date +%s)

    grep "<AdresDomeny>" "$hazard_zones_file" | while read -r line; do
        local domain=$(echo "$line" | grep -oP '(?<=<AdresDomeny>).*?(?=</AdresDomeny>)')

        if [ -n "$domain" ]; then
            for server in "${dns_servers[@]}"; do
                if dig @$server +short "$domain" > /dev/null; then
                    # Save the successful result in the results file
                    echo "$domain DNS: $server result OK" >> "$results_file"
                else
                    # Add the domain address and used DNS server to the problematic domains file
                    echo "$domain - does not resolve on DNS server: $server" >> "$problem_domains_file"
                fi
            done
            
            ((processed_domains++))

            # Calculate analyzing speed if duration is greater than zero
            local current_time=$(date +%s)
            local duration=$((current_time - start_time))
            if [ "$duration" -gt 0 ]; then
                local analyze_speed=$(echo "scale=2; $processed_domains / $duration" | bc)  # Domains per second
            else
                local analyze_speed=0
            fi

            local progress=$((processed_domains * 100 / total_domains))
            echo -ne "Progress: $progress% - Analyzing speed: ${analyze_speed} domains/s \r"
        fi
    done
    echo -ne "\n"
    local end_time=$(date +%s)
    local analysis_duration=$((end_time - start_time))
    echo "Analysis time: ${analysis_duration} seconds"
}

# Main script logic
script_start_time=$(date +%s)

# Fetch data in test mode
if [ "$test_mode" = true ]; then
    fetch_data
    echo "In test mode: checking the latest 10 domains..."
    # Fetch the latest domains for testing
    latest_domains=$(grep "<AdresDomeny>" "$hazard_zones_file" | head -n 10)
    echo "$latest_domains" > "$hazard_zones_file"
else
    fetch_data
fi

analyze_results

# Prepare the message for successful test
if [ -s "$results_file" ]; then
    message="Test OK: all domains resolved correctly.\n"
    if [ "$test_mode" = true ]; then
        message+="\nTested domains:\n"
        message+="\nDomain Name             | DNS Server       | Result\n"
        message+="-------------------------|------------------|--------\n"
        while IFS= read -r line; do
            # Format the output into a table
            message+="$(echo "$line" | awk -F' ' '{printf "%-24s| %-16s| %s\n", $1, $3, $5}')\n"
        done < "$results_file"
        message+="\nUsing DNS servers:\n${dns_servers[*]}\n"
        message+="Total execution time: $(( $(date +%s) - script_start_time )) seconds\n"
    fi
    send_email "$message"
else
    send_email "Test FAILED: found issues with the following domains"
fi

# Summary of total time
script_end_time=$(date +%s)
total_duration=$((script_end_time - script_start_time))
echo "Total script execution time: ${total_duration} seconds"

# Cleanup
rm -f "$hazard_zones_file" "$results_file" "$problem_domains_file"
