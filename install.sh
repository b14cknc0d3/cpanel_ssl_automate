#!/bin/bash

#######################################################
# SSL Automation - One-Click Installer
# Generic cPanel SSL certificate automation
#
# Usage: curl -fsSL https://raw.githubusercontent.com/b14cknc0d3/cpanel_ssl_automate/main/install.sh | bash
#
#######################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'

# Configuration
CONFIG_FILE="$HOME/.ssl-automation.config"
ACME_HOME="$HOME/.acme.sh"
ACME_SH="$ACME_HOME/acme.sh"
LOG_FILE="$HOME/ssl-automation.log"

#######################################################
# Logging functions
#######################################################
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

#######################################################
# Banner
#######################################################
show_banner() {
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   SSL Automation - One-Click Installer    ║"
    echo "║      Free SSL for cPanel Shared Hosting   ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

#######################################################
# Collect configuration
#######################################################
collect_config() {
    echo -e "${YELLOW}=== Configuration Setup ===${NC}"
    echo ""

    # Check for existing config
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}Found existing configuration:${NC}"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        echo -e "  Domain: ${DOMAIN}"
        echo -e "  Email: ${EMAIL}"
        echo ""
        read -r -p "Use existing config? (Y/n): " use_existing </dev/tty
        if [[ ! "$use_existing" =~ ^[Nn]$ ]]; then
            return 0
        fi
    fi

    # Collect email
    read -r -p "Enter your email address: " EMAIL </dev/tty
    while [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        error "Invalid email format"
        read -r -p "Enter your email address: " EMAIL </dev/tty
    done

    # Collect domain
    read -r -p "Enter your domain (e.g., example.com): " DOMAIN </dev/tty
    while [ -z "$DOMAIN" ]; do
        error "Domain cannot be empty"
        read -r -p "Enter your domain: " DOMAIN </dev/tty
    done

    # WWW subdomain
    read -r -p "Include www.$DOMAIN? (Y/n): " include_www </dev/tty
    if [[ ! "$include_www" =~ ^[Nn]$ ]]; then
        WWW_DOMAIN="www.$DOMAIN"
    else
        WWW_DOMAIN=""
    fi

    # Auto-detect cPanel username
    CPANEL_USERNAME=$(whoami)
    log "✓ Detected cPanel username: $CPANEL_USERNAME"

    # Auto-detect webroot
    WEBROOT_PATH="$HOME/public_html"
    if [ -d "$WEBROOT_PATH" ]; then
        log "✓ Detected webroot: $WEBROOT_PATH"
    else
        read -r -p "Enter webroot path: " WEBROOT_PATH </dev/tty
    fi

    # Auto-detect hostname
    CPANEL_HOST=$(hostname 2>/dev/null || echo "$DOMAIN")
    log "✓ Detected hostname: $CPANEL_HOST"

    # Save configuration
    cat > "$CONFIG_FILE" << EOF
# SSL Automation Configuration
# Generated on $(date)
EMAIL="$EMAIL"
DOMAIN="$DOMAIN"
WWW_DOMAIN="$WWW_DOMAIN"
CPANEL_USERNAME="$CPANEL_USERNAME"
WEBROOT_PATH="$WEBROOT_PATH"
CPANEL_HOST="$CPANEL_HOST"
EOF

    chmod 600 "$CONFIG_FILE"
    echo ""
    log "✓ Configuration saved to $CONFIG_FILE"
    echo ""
}

#######################################################
# Check if acme.sh is installed
#######################################################
check_acme() {
    log "Checking acme.sh installation..."

    if [ ! -f "$ACME_SH" ]; then
        log "Installing acme.sh..."
        curl -s https://get.acme.sh | sh -s email="$EMAIL" 2>&1 | tee -a "$LOG_FILE"

        # Source the profile to make acme.sh available
        # shellcheck source=/dev/null
        [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
        # shellcheck source=/dev/null
        [ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile"

        if [ -f "$ACME_SH" ]; then
            log "✓ acme.sh installed successfully"
        else
            error "Failed to install acme.sh"
            exit 1
        fi
    else
        log "✓ acme.sh is already installed"
        ACME_VERSION=$($ACME_SH --version 2>/dev/null | head -n1)
        log "Version: $ACME_VERSION"
    fi

    # Register account with Let's Encrypt and set as default CA
    log "Registering account with Let's Encrypt..."
    $ACME_SH --register-account -m "$EMAIL" --server letsencrypt 2>&1 | tee -a "$LOG_FILE" || true
    $ACME_SH --set-default-ca --server letsencrypt 2>&1 | tee -a "$LOG_FILE" || true
    log "✓ Using Let's Encrypt as certificate authority"
}

#######################################################
# Check webroot accessibility
#######################################################
check_webroot() {
    log "Checking webroot path: $WEBROOT_PATH"

    if [ ! -d "$WEBROOT_PATH" ]; then
        error "Webroot not found: $WEBROOT_PATH"
        exit 1
    fi

    if [ ! -w "$WEBROOT_PATH" ]; then
        error "No write permission to webroot: $WEBROOT_PATH"
        exit 1
    fi

    log "✓ Webroot is accessible and writable"
}

#######################################################
# Obtain SSL certificate
#######################################################
obtain_certificate() {
    log "Obtaining SSL certificate for $DOMAIN..."

    # Build domain arguments
    local domain_args="-d $DOMAIN"
    if [ -n "$WWW_DOMAIN" ]; then
        domain_args="$domain_args -d $WWW_DOMAIN"
        log "Including www subdomain: $WWW_DOMAIN"
    fi

    # Check if there's a failed/broken certificate entry
    if $ACME_SH --list 2>/dev/null | grep -q "$DOMAIN"; then
        log "Found existing certificate entry for $DOMAIN"

        # Check if certificate files actually exist
        local CERT_DIR="$ACME_HOME/${DOMAIN}"
        local ECC_CERT_DIR="$ACME_HOME/${DOMAIN}_ecc"

        if [ ! -f "$CERT_DIR/${DOMAIN}.cer" ] && [ ! -f "$ECC_CERT_DIR/${DOMAIN}.cer" ]; then
            log "Certificate files missing, removing broken entry..."
            $ACME_SH --remove -d "$DOMAIN" 2>&1 | tee -a "$LOG_FILE" || true

            # Also try removing ECC variant
            if [ -d "$ECC_CERT_DIR" ]; then
                log "Removing broken ECC certificate directory..."
                rm -rf "$ECC_CERT_DIR"
            fi

            log "Issuing fresh certificate with Let's Encrypt..."
            # shellcheck disable=SC2086
            $ACME_SH --issue $domain_args -w "$WEBROOT_PATH" --server letsencrypt --log "$LOG_FILE" 2>&1 | tee -a "$LOG_FILE"
        else
            log "Certificate files exist. Attempting renewal..."
            # shellcheck disable=SC2086
            $ACME_SH --renew $domain_args --force --server letsencrypt 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        log "Obtaining new certificate using webroot mode..."
        # shellcheck disable=SC2086
        $ACME_SH --issue $domain_args -w "$WEBROOT_PATH" --server letsencrypt --log "$LOG_FILE" 2>&1 | tee -a "$LOG_FILE"
    fi

    # Check if certificate files actually exist (try both regular and ECC directories)
    local CERT_DIR="$ACME_HOME/${DOMAIN}"
    local ECC_CERT_DIR="$ACME_HOME/${DOMAIN}_ecc"

    if [ -f "$CERT_DIR/${DOMAIN}.cer" ] && [ -f "$CERT_DIR/${DOMAIN}.key" ]; then
        log "✓ Certificate obtained successfully!"
        log "Certificate location: $CERT_DIR"
        return 0
    elif [ -f "$ECC_CERT_DIR/${DOMAIN}.cer" ] && [ -f "$ECC_CERT_DIR/${DOMAIN}.key" ]; then
        log "✓ Certificate obtained successfully (ECC)!"
        log "Certificate location: $ECC_CERT_DIR"
        return 0
    else
        error "Failed to obtain certificate - files not found"
        error "Expected location: $CERT_DIR or $ECC_CERT_DIR"
        error "Check the log for details: $LOG_FILE"
        return 1
    fi
}

#######################################################
# Deploy certificate to cPanel
#######################################################
deploy_to_cpanel() {
    log "Deploying certificate to cPanel..."

    if $ACME_SH --deploy -d "$DOMAIN" --deploy-hook cpanel_uapi 2>&1 | tee -a "$LOG_FILE"; then
        log "✓ Certificate deployed to cPanel successfully!"
        return 0
    else
        warning "Automatic cPanel deployment failed"
        copy_certificates_manual
        return 1
    fi
}

#######################################################
# Copy certificates for manual installation
#######################################################
copy_certificates_manual() {
    local CERT_DIR="$ACME_HOME/${DOMAIN}"
    local SSL_DIR="$HOME/ssl-certs"

    if [ ! -d "$CERT_DIR" ]; then
        error "Certificate directory not found: $CERT_DIR"
        return 1
    fi

    mkdir -p "$SSL_DIR"

    # Copy certificates with readable names
    cp "$CERT_DIR/fullchain.cer" "$SSL_DIR/certificate.crt" 2>/dev/null
    cp "$CERT_DIR/${DOMAIN}.key" "$SSL_DIR/private.key" 2>/dev/null
    cp "$CERT_DIR/ca.cer" "$SSL_DIR/ca_bundle.crt" 2>/dev/null

    chmod 600 "$SSL_DIR"/*

    log ""
    log "Certificates copied to: $SSL_DIR"
    log "Manual installation required:"
    log "  1. Log into cPanel"
    log "  2. Go to Security > SSL/TLS > Manage SSL Sites"
    log "  3. Select domain: $DOMAIN"
    log "  4. Copy and paste the certificate files from $SSL_DIR"
    log ""

    return 0
}

#######################################################
# Setup auto-renewal cron job
#######################################################
setup_cron() {
    log "Setting up auto-renewal cron job..."

    # Remove any broken cron jobs first
    crontab -l 2>/dev/null | grep -v "acme.sh.*--cron" | crontab - 2>/dev/null || true

    # Add correct cron job
    local CRON_CMD="0 0 * * * $ACME_SH --cron --home $ACME_HOME > /dev/null"

    log "Adding cron job for automatic renewal..."
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

    if [ $? -eq 0 ]; then
        log "✓ Auto-renewal cron job added"
        log ""
        log "Cron job installed:"
        log "  $CRON_CMD"
        log ""
        log "Schedule: Daily at midnight (00:00)"
        log "Certificates will auto-renew 60 days before expiry"
    else
        warning "Failed to add cron job"
    fi
}

#######################################################
# Check certificate expiry
#######################################################
check_expiry() {
    local CERT_FILE="$ACME_HOME/${DOMAIN}/fullchain.cer"

    if [ -f "$CERT_FILE" ] && command -v openssl &> /dev/null; then
        EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
        log "Certificate expires on: $EXPIRY_DATE"

        # Calculate days until expiry
        if date -v+1d &>/dev/null 2>&1; then
            # BSD date (macOS)
            EXPIRY_EPOCH=$(date -jf "%b %d %T %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null)
        else
            # GNU date (Linux)
            EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
        fi

        if [ -n "$EXPIRY_EPOCH" ]; then
            CURRENT_EPOCH=$(date +%s)
            DAYS_UNTIL_EXPIRY=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

            if [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
                warning "Certificate expires in $DAYS_UNTIL_EXPIRY days!"
            else
                log "Certificate valid for $DAYS_UNTIL_EXPIRY more days"
            fi
        fi
    fi
}

#######################################################
# Show completion summary
#######################################################
enable_https_redirect() {
    log "Enabling HTTPS redirect..."

    local HTACCESS="$WEBROOT_PATH/.htaccess"

    # Check if redirect already exists
    if [ -f "$HTACCESS" ] && grep -q "RewriteEngine On" "$HTACCESS" && grep -q "HTTPS" "$HTACCESS"; then
        log "HTTPS redirect already configured in .htaccess"
        return 0
    fi

    # Backup existing .htaccess
    if [ -f "$HTACCESS" ]; then
        cp "$HTACCESS" "$HTACCESS.backup.$(date +%s)"
        log "Backed up existing .htaccess"
    fi

    # Add HTTPS redirect
    cat > "$HTACCESS.new" << 'EOF'
# Force HTTPS redirect
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

EOF

    # Append existing content if any
    if [ -f "$HTACCESS" ]; then
        cat "$HTACCESS" >> "$HTACCESS.new"
    fi

    mv "$HTACCESS.new" "$HTACCESS"
    log "✓ HTTPS redirect enabled in .htaccess"
}

show_completion() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         SSL Setup Complete!                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Configuration Summary:${NC}"
    echo -e "  Domain: ${BLUE}$DOMAIN${NC}"
    [ -n "$WWW_DOMAIN" ] && echo -e "  WWW: ${BLUE}$WWW_DOMAIN${NC}"
    echo -e "  Email: ${BLUE}$EMAIL${NC}"
    echo -e "  Config: ${BLUE}$CONFIG_FILE${NC}"
    echo ""
    echo -e "${GREEN}✓ SSL Certificate Installed${NC}"
    echo -e "${GREEN}✓ HTTPS Redirect Enabled${NC}"
    echo -e "${GREEN}✓ Auto-Renewal Configured${NC}"
    echo ""
    echo -e "${YELLOW}Test your site:${NC}"
    echo -e "  ${BLUE}https://$DOMAIN${NC}"
    [ -n "$WWW_DOMAIN" ] && echo -e "  ${BLUE}https://$WWW_DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}Verify cron job:${NC}"
    echo -e "  ${BLUE}crontab -l | grep acme${NC}"
    echo ""
    echo -e "${YELLOW}Important:${NC}"
    echo -e "  • Clear browser cache if you see warnings"
    echo -e "  • It may take 1-2 minutes for SSL to activate"
    echo -e "  • Certificate auto-renews 60 days before expiry"
    echo ""
    echo -e "${YELLOW}To manually renew:${NC}"
    echo -e "  ${BLUE}$ACME_SH --renew -d $DOMAIN --force${NC}"
    echo ""
    echo -e "Logs: ${BLUE}$LOG_FILE${NC}"
    echo ""
}

#######################################################
# Main execution
#######################################################
main() {
    show_banner

    log "=== SSL Automation Started ==="

    # Collect configuration
    collect_config

    # Load config
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    log "Domain: $DOMAIN"
    log "Email: $EMAIL"
    echo ""

    # Check and install acme.sh
    check_acme

    # Check webroot
    check_webroot

    # Obtain certificate
    if obtain_certificate; then
        # Deploy to cPanel
        deploy_to_cpanel

        # Setup auto-renewal
        setup_cron

        # Check expiry
        check_expiry

        # Enable HTTPS redirect
        enable_https_redirect

        # Show completion
        show_completion
    else
        error "SSL setup failed. Check logs: $LOG_FILE"
        exit 1
    fi

    log "=== SSL Automation Completed ==="
}

# Run main function
main