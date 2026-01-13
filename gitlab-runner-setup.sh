#!/bin/bash
# GitLab Runner Setup Script for Ansible Playbooks
# This script helps set up a GitLab runner for running Ansible playbooks

set -e

echo "=========================================="
echo "GitLab Runner Setup for Ansible Playbooks"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}Cannot detect OS${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: $OS $VER${NC}"

# Install GitLab Runner
install_gitlab_runner() {
    echo -e "${YELLOW}Installing GitLab Runner...${NC}"
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
        apt-get install -y gitlab-runner
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
        curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash
        yum install -y gitlab-runner
    else
        echo -e "${RED}Unsupported OS: $OS${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}GitLab Runner installed successfully${NC}"
}

# Install Ansible and dependencies
install_ansible() {
    echo -e "${YELLOW}Installing Ansible and dependencies...${NC}"
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt-get update
        apt-get install -y ansible python3-pip python3-venv
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ]; then
        yum install -y epel-release
        yum install -y ansible python3-pip
    elif [ "$OS" = "fedora" ]; then
        dnf install -y ansible python3-pip
    fi
    
    # Install Python dependencies for VMware
    echo -e "${YELLOW}Installing Python dependencies for VMware...${NC}"
    pip3 install --upgrade pip
    pip3 install pyvmomi requests
    
    # Install Ansible VMware collection
    echo -e "${YELLOW}Installing Ansible VMware collection...${NC}"
    ansible-galaxy collection install vmware.vmware_rest || echo -e "${YELLOW}Warning: Could not install vmware.vmware_rest collection${NC}"
    
    echo -e "${GREEN}Ansible installed successfully${NC}"
}

# Create directory structure
create_directories() {
    echo -e "${YELLOW}Creating directory structure...${NC}"
    
    mkdir -p /opt/jenkins/inventories/fse
    mkdir -p /opt/jenkins/secrets
    
    # Set ownership to gitlab-runner user
    if id "gitlab-runner" &>/dev/null; then
        chown -R gitlab-runner:gitlab-runner /opt/jenkins/inventories
        chown -R gitlab-runner:gitlab-runner /opt/jenkins/secrets
        echo -e "${GREEN}Directories created and ownership set${NC}"
    else
        echo -e "${YELLOW}Warning: gitlab-runner user does not exist yet. Run this after registering the runner.${NC}"
        echo -e "${YELLOW}You can set ownership later with:${NC}"
        echo -e "${YELLOW}  chown -R gitlab-runner:gitlab-runner /opt/jenkins/inventories${NC}"
        echo -e "${YELLOW}  chown -R gitlab-runner:gitlab-runner /opt/jenkins/secrets${NC}"
    fi
}

# Setup SSH configuration
setup_ssh() {
    echo -e "${YELLOW}Setting up SSH configuration...${NC}"
    
    RUNNER_HOME="/home/gitlab-runner"
    if [ -d "$RUNNER_HOME" ]; then
        mkdir -p "$RUNNER_HOME/.ssh"
        chmod 700 "$RUNNER_HOME/.ssh"
        chown -R gitlab-runner:gitlab-runner "$RUNNER_HOME/.ssh"
        echo -e "${GREEN}SSH directory created${NC}"
        echo -e "${YELLOW}Note: You need to add the Ansible private key to $RUNNER_HOME/.ssh/ or /opt/jenkins/secrets/ansible.key${NC}"
    else
        echo -e "${YELLOW}Warning: gitlab-runner home directory does not exist yet${NC}"
    fi
}

# Main installation
main() {
    echo -e "${GREEN}Starting installation...${NC}"
    
    install_gitlab_runner
    install_ansible
    create_directories
    setup_ssh
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo -e "Installation Complete!"
    echo -e "==========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Register the runner:"
    echo "   sudo gitlab-runner register"
    echo ""
    echo "2. Copy your inventory files:"
    echo "   sudo cp -r /path/to/fse-internal /opt/jenkins/inventories/fse/"
    echo "   sudo chown -R gitlab-runner:gitlab-runner /opt/jenkins/inventories/fse/fse-internal"
    echo ""
    echo "3. Copy your secrets:"
    echo "   sudo cp /path/to/ansible.key /opt/jenkins/secrets/"
    echo "   sudo chmod 600 /opt/jenkins/secrets/ansible.key"
    echo "   sudo chown gitlab-runner:gitlab-runner /opt/jenkins/secrets/ansible.key"
    echo ""
    echo "   echo 'your-vault-password' | sudo tee /opt/jenkins/secrets/vault.txt"
    echo "   sudo chmod 600 /opt/jenkins/secrets/vault.txt"
    echo "   sudo chown gitlab-runner:gitlab-runner /opt/jenkins/secrets/vault.txt"
    echo ""
    echo "4. Verify runner status:"
    echo "   sudo gitlab-runner status"
    echo ""
    echo "5. Test the runner:"
    echo "   sudo gitlab-runner verify"
    echo ""
}

# Run main function
main

