# Oxidized Docker

A containerized deployment of Oxidized network configuration backup tool with HashiCorp Vault integration for secure secrets management.

## Overview

This project provides a Docker-based deployment of Oxidized with the following features:
- Automated network device configuration backup
- Web interface for configuration management
- Git integration for version control
- HashiCorp Vault integration for secrets management
- Custom views and styling with dark mode support
- Syslog hook for sending notifications to external syslog servers

## Components

### Oxidized Service
- Main configuration backup service
- Web interface accessible on port 8888
- Git integration for configuration versioning
- Custom views and styling through HAML templates
- Vault integration for secure credentials management
- SSH keys dynamically retrieved from Vault at startup
- Syslog hook for sending backup notifications to external syslog server

## Prerequisites

- Docker
- Docker Compose
- Git access for configuration repository
- HashiCorp Vault (optional, for secrets management)
- Netbox (optional, for device discovery)

## Installation

1. Clone this repository:
```bash
git clone <your-repository-url>
cd oxidized-docker
```

2. Configure environment variables:
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your configuration
# At minimum, configure:
# - VAULT_ADDR and VAULT_TOKEN (if using Vault)
# - GIT_REMOTE_REPO (your Git repository URL)
```

3. Configure your Vault secrets (if using Vault):

The application expects the following secrets in Vault under the path `secret/oxidized/`:

```
secret/oxidized/
├── netbox/
│   ├── token          # Netbox API token
│   └── addr           # Netbox URL
├── oxidized/
│   ├── private_key    # SSH private key for Git operations
│   └── public_key     # SSH public key
├── network/read-write/
│   ├── username       # Network device username
│   └── password       # Network device password
└── panorama/          # Optional: for PAN-OS devices
    ├── PAN_API_USER_RO
    └── PAN_API_PASS_RO
```

4. Customize the configuration:
```bash
# Edit oxidized/config.template to match your environment:
# - Update the Netbox URL (or use a different source)
# - Configure device models and credentials
# - Adjust Git repository settings
```

5. Start the services:
```bash
docker compose up -d
```

## Configuration

### Git Repository Setup

Configure your Git remote repository in `docker-compose.yml` or `.env`:
```yaml
environment:
  - GIT_REMOTE_REPO=git@github.com:your-org/oxidized-configs.git
```

Supported Git providers:
- GitHub
- GitLab
- Bitbucket
- Self-hosted Git servers

### Device Source Configuration

The default configuration uses Netbox as the device source. You can configure alternative sources in `oxidized/config.template`:

**Option 1: Netbox (default)**
```yaml
source:
  default: http
  http:
    url: "https://netbox.example.com/api/dcim/devices/?status=active&has_primary_ip=true"
    headers:
      Authorization: "Token __NETBOX_TOKEN__"
```

**Option 2: CSV File**
```yaml
source:
  default: csv
  csv:
    file: /home/oxidized/.config/oxidized/router.db
    delimiter: ":"
    map:
      name: 0
      model: 1
      ip: 2
```

**Option 3: Static Configuration**
Add devices directly in the config file (for testing):
```yaml
source:
  default: csv
  csv:
    file: ~/.config/oxidized/router.db
```

### Custom Components

#### Output Formatter
The custom Git output formatter (`oxidized/custom_files/output/git.rb`) extends the default Git output functionality by:
- Automatically appending `.cfg` extension to configuration files
- Supporting group-based repository organization
- Maintaining commit history and version control
- Handling both single and multi-repository setups

#### Custom PAN-OS API Model
The custom PAN-OS API model (`oxidized/model/panos_api.rb`) provides enhanced functionality for Palo Alto Networks devices:
- Retrieves both local and Panorama-pushed configurations
- Supports multiple output formats (dictionary and XML)
- Filters Panorama template configurations
- Automatically converts XML configurations to set commands
- Uses secure HTTPS API communication

#### Custom Views
Custom views are located in `/oxidized/custom_files/views/`:
- `layout.haml`: Main layout template with dark mode toggle
- `nodes.haml`: Device list view
- `node.haml`: Individual device view
- `stats.haml`: Statistics view

#### Custom Styling
Custom CSS with dark mode support is available in `/oxidized/custom_files/assets/custom.css`

### Secrets Management

#### Option 1: HashiCorp Vault (Recommended)
The project includes integration with HashiCorp Vault for secure secrets management. See `oxidized/secrets.py` for the implementation.

To customize for your Vault structure:
1. Copy `oxidized/secrets.example.py` to `oxidized/secrets.py`
2. Modify the `VAULT_PREFIX_PATH` and `vault_paths` to match your Vault structure
3. Update the `init_secrets()` function to fetch your required secrets

#### Option 2: Environment Variables
For development or simple deployments, you can set secrets directly as environment variables in `.env` (not recommended for production).

#### Option 3: Docker Secrets
You can also use Docker secrets or other secrets management solutions by modifying the entrypoint script.

## Usage

1. Access the web interface:
   - Open http://localhost:8888 in your browser
   - View and manage device configurations
   - Access backup history and search configurations

2. Working with Configurations:
   - Configurations are automatically backed up based on the interval (default: 24 hours)
   - Automatic commits to Git on changes
   - History and versioning available through web interface
   - Changes are pushed to remote repository automatically

## Project Structure

```
├── docker-compose.yml          # Docker services configuration
├── .env.example               # Example environment variables
├── README.PUBLIC.md           # This file
└── oxidized/                  # Main Oxidized service
    ├── Dockerfile            # Oxidized container build
    ├── config.template       # Oxidized configuration template
    ├── entrypoint.sh         # Container startup script
    ├── secrets.py            # Vault integration script
    ├── secrets.example.py    # Example secrets script
    ├── requirements.txt      # Python dependencies
    ├── custom_files/         # Custom views and assets
    │   ├── assets/          # Custom styling (CSS)
    │   ├── views/           # HAML templates
    │   ├── output/          # Output formatters
    │   └── source/          # Custom source plugins
    ├── hooks/               # Custom hooks
    │   └── syslog_hook.sh   # Syslog notification hook
    ├── model/               # Device models
    │   └── panos_api.rb     # PAN-OS API model
    └── scripts/             # Utility scripts
        └── panos_xml_to_set.py
```

## Supported Devices

The following device models are supported out of the box:
- Cisco IOS / IOS-XE
- Cisco NX-OS
- Arista EOS
- Extreme XOS
- Palo Alto PAN-OS (via API)

Additional models can be added - see [Oxidized documentation](https://github.com/ytti/oxidized) for supported devices.

## Dependencies

### Oxidized Service
- xmltodict: XML parsing for API interactions
- hvac: HashiCorp Vault integration for secure secrets management

## Security Best Practices

- SSH keys for Git operations are dynamically retrieved from Vault at container startup
- All sensitive credentials should be stored in Vault or another secrets management solution
- Never commit private keys or passwords to version control
- Container runs with restart policy for high availability
- Use SSH key authentication for Git operations instead of passwords
- Regularly rotate network device credentials and update in Vault

## Troubleshooting

### Container won't start
- Check Docker logs: `docker logs oxidized`
- Verify Vault connectivity and credentials
- Ensure Git repository is accessible with provided SSH key

### Devices not showing up
- Check Netbox API connectivity and token
- Verify device source configuration in `config.template`
- Check device filters in the API query

### Git push failures
- Verify SSH key is correctly configured in Vault
- Check Git repository permissions
- Ensure SSH host key is added (see `entrypoint.sh`)

### Configuration backups failing
- Verify network device credentials in Vault
- Check device connectivity from container
- Review Oxidized logs for specific errors

## Customization

### Adding New Device Types
1. Add the model to `oxidized/model/` directory
2. Update `config.template` to include model credentials
3. Update `model_map` section to map platform names

### Modifying the UI
- Edit HAML templates in `oxidized/custom_files/views/`
- Modify CSS in `oxidized/custom_files/assets/custom.css`
- Rebuild container: `docker compose up -d --build`

### Adding Custom Hooks
- Add hook scripts to `oxidized/hooks/`
- Configure hooks in `config.template`
- Make scripts executable: `chmod +x hook_script.sh`

## Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Create a new Pull Request

## License

This project is provided as-is for network automation purposes. Please review the licenses of the included components (Oxidized, etc.) for their respective terms.

## Acknowledgments

- [Oxidized](https://github.com/ytti/oxidized) - The core network device configuration backup tool
- HashiCorp Vault - Secrets management
- Docker community - Containerization support
