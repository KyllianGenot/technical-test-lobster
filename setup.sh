#!/bin/bash

# Colors for output
PRIMARY='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
WARN='\033[0;33m'
WHITE='\033[0;37m'
RESET='\033[0m'
BOLD='\033[1m'

# Symbols
CHECK="✓"
CROSS="✗"
ARROW="→"

# Spinner frames for loading animation
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# Function to display spinner during operations
show_spinner() {
    local pid=$1
    local message=$2
    local i=0
    
    echo -ne "\r\033[K${PRIMARY}${SPINNER_FRAMES[0]} ${message}${RESET}"
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % ${#SPINNER_FRAMES[@]} ))
        echo -ne "\r\033[K${PRIMARY}${SPINNER_FRAMES[$i]} ${message}${RESET}"
        sleep 0.1
    done
    echo -ne "\r\033[K"  # Clear the line after spinner
}

# Progress function with spinner start
start_progress() {
    echo -ne "\r\033[K${PRIMARY}${SPINNER_FRAMES[0]} ${BOLD}$1${RESET}"
}

# Update progress (for longer operations)
update_progress() {
    echo -ne "\r\033[K${PRIMARY}${SPINNER_FRAMES[$(($RANDOM % 10))]} ${BOLD}$1${RESET}"
}

# Success function for completed steps
show_success() {
    echo -e "\r\033[K${SUCCESS}${CHECK} $1${RESET}"
}

# Error function for failures
show_error() {
    echo -e "\r\033[K${ERROR}${CROSS} $1${RESET}"
    exit 1
}

# Info function for general information
show_info() {
    echo -e "\r\033[K${WARN}${ARROW} $1${RESET}"
}

# Section header with dynamic centering
show_section() {
    local title=$1
    local width=68
    local padding=$(( (width - ${#title}) / 2 ))
    local left_padding=$(printf "%${padding}s" "")
    echo -e "\n${WHITE}────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${WHITE}${left_padding}${title}${left_padding// / }${RESET}"
    echo -e "${WHITE}────────────────────────────────────────────────────────────────────${RESET}\n"
}

# Centered welcome message with ASCII art
show_welcome() {
    echo -e "\n"
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                                                                  ║${RESET}"
    echo -e "${WHITE}║    ██╗      ██████╗ ██████╗ ███████╗████████╗███████╗██████╗     ║${RESET}"
    echo -e "${WHITE}║    ██║     ██╔═══██╗██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗    ║${RESET}"
    echo -e "${WHITE}║    ██║     ██║   ██║██████╔╝███████╗   ██║   █████╗  ██████╔╝    ║${RESET}"
    echo -e "${WHITE}║    ██║     ██║   ██║██╔══██╗╚════██║   ██║   ██╔==╝  ██╔══██╗    ║${RESET}"
    echo -e "${WHITE}║    ███████╗╚██████╔╝██████╔╝███████║   ██║   ███████╗██║  ██║    ║${RESET}"
    echo -e "${WHITE}║    ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝    ║${RESET}"
    echo -e "${WHITE}║                                                                  ║${RESET}"
    echo -e "${WHITE}║                       TECHNICAL TEST SETUP                       ║${RESET}"
    echo -e "${WHITE}║                                                                  ║${RESET}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo -e "\nThis script will set up everything you need to run the application.\n"
}

# Function to ensure sudo privileges are available
ensure_sudo() {
    echo -e "${PRIMARY}${ARROW} This script requires sudo privileges${RESET}"
    if ! sudo -n true 2>/dev/null; then
        echo -e "${WARN}${ARROW} Please enter your sudo password:${RESET}"
        sudo -v || show_error "Failed to obtain sudo privileges"
    fi
    # Keep sudo alive during script execution
    (while true; do sudo -n true; sleep 60; done) &
    local sudo_pid=$!
    trap "kill $sudo_pid 2>/dev/null; exit" EXIT INT TERM
    show_success "Sudo privileges confirmed"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package with OS-specific logic
install_package() {
    local package=$1
    if ! command_exists "$package"; then
        start_progress "Installing $package"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install "$package" > /dev/null 2>&1 &
            show_spinner $! "Installing $package"
            if [ $? -eq 0 ]; then
                show_success "Installing $package"
            else
                show_error "Failed to install $package"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if ! command_exists apt; then
                show_error "apt not found, please install $package manually"
            fi
            (sudo apt update > /dev/null 2>&1 && sudo apt install -y "$package" > /dev/null 2>&1) &
            show_spinner $! "Installing $package"
            if [ $? -eq 0 ]; then
                show_success "Installing $package"
            else
                show_error "Failed to install $package"
            fi
        else
            show_error "Unsupported OS. Please install $package manually"
        fi
    fi
}

# Function to stop all related processes
stop_processes() {
    start_progress "Stopping any running instances"
    if sudo lsof -i :8080 >/dev/null 2>&1; then
        sudo lsof -i :8080 | grep LISTEN | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1 || true
    fi
    pkill -9 cargo >/dev/null 2>&1 || true
    pkill -9 technical-test-lobster >/dev/null 2>&1 || true
    show_success "Stopping any running instances"
}

# Display welcome message and ensure sudo
show_welcome
ensure_sudo

# 1. Install Prerequisites
show_section "DEVELOPMENT ENVIRONMENT SETUP"

# Rust
if ! command_exists rustc || ! command_exists cargo; then
    start_progress "Installing Rust"
    (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1) &
    show_spinner $! "Installing Rust"
    if [ $? -eq 0 ]; then
        source "$HOME/.cargo/env" > /dev/null 2>&1 || show_error "Failed to source Rust environment"
        show_success "Installing Rust"
    else
        show_error "Failed to install Rust"
    fi
fi

# PostgreSQL
if ! command_exists psql; then
    install_package postgresql
fi

# Install PostgreSQL development libraries
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! brew list libpq >/dev/null 2>&1; then
        start_progress "Installing PostgreSQL dev libraries"
        (brew install libpq > /dev/null 2>&1) &
        show_spinner $! "Installing PostgreSQL dev libraries"
        if [ $? -eq 0 ]; then
            show_success "Installing PostgreSQL dev libraries"
        else
            show_error "Failed to install PostgreSQL dev libraries"
        fi
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! dpkg -l | grep -q libpq-dev; then
        start_progress "Installing PostgreSQL dev libraries"
        (sudo apt update > /dev/null 2>&1 && sudo apt install -y libpq-dev > /dev/null 2>&1) &
        show_spinner $! "Installing PostgreSQL dev libraries"
        if [ $? -eq 0 ]; then
            show_success "Installing PostgreSQL dev libraries"
        else
            show_error "Failed to install PostgreSQL dev libraries"
        fi
    fi
fi

# Install development tools
start_progress "Installing development tools"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! command_exists pkg-config; then
        (sudo apt install -y pkg-config > /dev/null 2>&1) &
        show_spinner $! "Installing pkg-config"
    fi
    if ! dpkg -l | grep -q libssl-dev; then
        (sudo apt install -y libssl-dev > /dev/null 2>&1) &
        show_spinner $! "Installing libssl-dev"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! brew list pkg-config >/dev/null 2>&1; then
        (brew install pkg-config > /dev/null 2>&1) &
        show_spinner $! "Installing pkg-config"
    fi
    if ! brew list openssl >/dev/null 2>&1; then
        (brew install openssl > /dev/null 2>&1) &
        show_spinner $! "Installing openssl"
    fi
fi
show_success "Installing development tools"

# Start PostgreSQL
start_progress "Starting database service"
if [[ "$OSTYPE" == "darwin"* ]]; then
    (brew services start postgresql > /dev/null 2>&1) &
    show_spinner $! "Starting database service"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    (sudo service postgresql start > /dev/null 2>&1) &
    show_spinner $! "Starting database service"
fi
sleep 2
show_success "Starting database service"

# Node.js and npm
if ! command_exists node || ! command_exists npm; then
    start_progress "Installing Node.js and npm"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        (brew install nodejs > /dev/null 2>&1) &
        show_spinner $! "Installing Node.js and npm"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        (sudo apt update > /dev/null 2>&1 && sudo apt install -y nodejs npm > /dev/null 2>&1) &
        show_spinner $! "Installing Node.js and npm"
    fi
    if [ $? -eq 0 ]; then
        show_success "Installing Node.js and npm"
    else
        show_error "Failed to install Node.js and npm"
    fi
fi

# Diesel CLI
if ! command_exists diesel; then
    start_progress "Installing Diesel CLI"
    (cargo install diesel_cli --no-default-features --features postgres > /dev/null 2>&1) &
    show_spinner $! "Installing Diesel CLI"
    if [ $? -eq 0 ]; then
        show_success "Installing Diesel CLI"
    else
        show_error "Failed to install Diesel CLI"
    fi
fi

# 2. Set Up the Database
show_section "DATABASE CONFIGURATION"
echo -e "${PRIMARY}* Setting up database${RESET}"
read -p "Enter PostgreSQL username [default: postgres]: " PG_USER
PG_USER=${PG_USER:-postgres}
read -p "Enter PostgreSQL password [press Enter if none]: " -s PG_PASS
echo ""  # Add newline after password input
read -p "Enter database name [default: lobster_db]: " DB_NAME
DB_NAME=${DB_NAME:-lobster_db}

# Set default password if none provided
if [ -z "$PG_PASS" ]; then
    DEFAULT_PASS="default_password"
    (sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$DEFAULT_PASS'" > /dev/null 2>&1) &
    show_spinner $! "Setting default password for database user"
    if [ $? -eq 0 ]; then
        PG_PASS=$DEFAULT_PASS
        show_info "Setting default password for database user"
    else
        show_error "Failed to set database password. Please run the script again with administrator privileges."
    fi
fi

# Create database if it doesn't exist
if ! PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
    start_progress "Creating database $DB_NAME"
    (PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -c "CREATE DATABASE $DB_NAME;" > /dev/null 2>&1) &
    show_spinner $! "Creating database $DB_NAME"
    if [ $? -eq 0 ]; then
        show_success "Creating database $DB_NAME"
    else
        show_error "Failed to create database"
    fi
fi

# 3. Install Dependencies
show_section "APPLICATION BUILD"
start_progress "Building application (this may take a few minutes)"
(cargo build --quiet) &
pid=$!
show_spinner $pid "Building application (this may take a few minutes)"
wait $pid
if [ $? -ne 0 ]; then
    show_error "Building application failed. Check your internet connection or Rust configuration."
fi
show_success "Building application"

# 4. Configure Frontend and Build
if [ -d "frontend" ]; then
    if [ ! -f "frontend/package.json" ]; then
        show_error "Frontend directory exists but package.json is missing. Please ensure the frontend is properly configured."
    fi
    start_progress "Setting up frontend"
    cd frontend
    (npm install > /dev/null 2>&1) &
    pid=$!
    show_spinner $pid "Installing frontend dependencies"
    wait $pid
    if [ $? -eq 0 ]; then
        show_success "Installing frontend dependencies"
        # Check if build script exists and configure it
        if [ -f "package.json" ] && grep -q '"build":' package.json; then
            start_progress "Configuring frontend build"
            npm pkg set scripts.build="vite build --outDir dist" > /dev/null 2>&1  # Adjust if not Vite
            show_success "Configuring frontend build"
        else
            show_info "No build script found in package.json. Assuming manual configuration."
        fi
        start_progress "Building frontend"
        (npm run build > /dev/null 2>&1) &
        pid=$!
        show_spinner $pid "Building frontend"
        wait $pid
        if [ $? -eq 0 ] && [ -d "dist" ]; then
            show_success "Building frontend"
        else
            show_error "Building frontend failed or dist directory not found."
        fi
    else
        show_error "Installing frontend dependencies failed."
    fi
    cd ..
    # Verify frontend/dist exists
    if [ -d "frontend/dist" ]; then
        show_success "Frontend build directory confirmed"
    else
        show_error "Frontend build directory (frontend/dist) not found"
    fi
else
    show_info "No frontend directory found. Skipping frontend setup."
fi

# 5. Configure .env
show_section "ENVIRONMENT CONFIGURATION"
echo -e "${PRIMARY}* Configuring environment${RESET}"
if [ -f ".env" ]; then
    read -p "Existing configuration found. Overwrite? (y/N): " overwrite
    if [[ "$overwrite" != [yY] ]]; then
        show_success "Configuring environment"
    else
        read -p "Enter Alchemy API key: " ALCHEMY_KEY
        if [ -z "$ALCHEMY_KEY" ]; then
            show_error "Configuring environment: Alchemy API key required"
        fi

        cat > .env << EOL
DATABASE_URL=postgres://$PG_USER${PG_PASS:+:$PG_PASS}@localhost/$DB_NAME
ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_KEY
ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
API_PORT=8080
EOL
        show_success "Configuring environment"
    fi
else
    read -p "Enter Alchemy API key: " ALCHEMY_KEY
    if [ -z "$ALCHEMY_KEY" ]; then
        show_error "Configuring environment: Alchemy API key required"
    fi

    cat > .env << EOL
DATABASE_URL=postgres://$PG_USER${PG_PASS:+:$PG_PASS}@localhost/$DB_NAME
ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_KEY
ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
API_PORT=8080
EOL
    show_success "Configuring environment"
fi

# 6. Apply Migrations
show_section "DATABASE MIGRATION"
start_progress "Setting up database schema"
source .env
(diesel migration run > /dev/null 2>&1) &
show_spinner $! "Setting up database schema"
if [ $? -eq 0 ]; then
    show_success "Setting up database schema"
else
    show_error "Setting up database schema. Check your PostgreSQL connection."
fi

# 7. Stop any existing processes
show_section "APPLICATION LAUNCH"
stop_processes

# 8. Launch Backend
show_success "Setup completed successfully!"
echo ""
read -p "Launch the application now? (Y/n): " launch
if [[ "$launch" != [nN] ]]; then
    # Trap Ctrl+C to stop all processes
    trap 'echo -e "\n${SUCCESS}Stopping application...${RESET}"; stop_processes; exit 0' INT

    # Launch backend in the foreground
    echo -e "\n${WHITE}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}          APPLICATION RUNNING AT http://localhost:8080          ${RESET}"
    echo -e "${WHITE}                    Press Ctrl+C to stop                    ${RESET}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════${RESET}\n"
    RUST_LOG=info cargo run
else
    echo -e "\n${SUCCESS}You can start the application manually with:${RESET}"
    echo -e "  RUST_LOG=info cargo run"
    echo ""
fi