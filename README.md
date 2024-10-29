# AuditDomainHazardDNS

A script to audit and resolve domains using specified DNS servers, fetching data from the hazard API.

## Overview

This script performs DNS resolution tests on a list of domains fetched from the hazard API. It checks if the domains can be resolved by specified DNS servers and sends an email with the results.


## Features

- Fetches domain data from the hazard API.
- Resolves domains using multiple DNS servers.
- Supports a test mode that checks the latest 10 domains.
- Sends email notifications with detailed results.
- Outputs results in a structured format.

## Requirements

- Bash
- `curl`
- `dig`
- `ssmtp` or another mail utility

## Usage

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd AuditDomainHazardDNS

2. Make the script executable:
```bash
chmod +x AuditDomainHazardDNS.sh
```
3. Run the script:
```bash
./AuditDomainHazardDNS.sh [--test]
```

## Configuration

You can customize the following variables in the script:

- `recipient_email`: Email addresses for the DNS server admins.
- `subject`: Subject line for the notification email.
- `dns_servers`: List of DNS servers to be tested.

## Email Notification Format

The email sent after the script execution contains:

- A summary of the results indicating whether all domains resolved correctly.
- A detailed table of tested domains, DNS servers used, and results.

## Cleanup
The script cleans up temporary files created during execution to avoid clutter.

## License
This project is licensed under the MIT License.
