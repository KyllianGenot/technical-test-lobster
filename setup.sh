#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Progress function to show clean output
show_progress() {
    echo -e "${GREEN}⏳ $1...${NC}"
}

# Success function for completed steps
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Error function for failures
show_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package with OS-specific logic
install_package() {
    local package=$1
    if ! command_exists "$package"; then
        show_progress "Installing $package"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if brew install "$package" > /dev/null 2>&1; then
                show_success "$package installed"
            else
                show_error "Failed to install $package"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if ! command_exists apt; then
                show_error "apt not found, please install $package manually"
            fi
            if sudo apt update > /dev/null 2>&1 && sudo apt install -y "$package" > /dev/null 2>&1; then
                show_success "$package installed"
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
    show_progress "Stopping any running instances"
    if sudo lsof -i :8080 >/dev/null 2>&1; then
        sudo lsof -i :8080 | grep LISTEN | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1 || true
    fi
    pkill -9 cargo >/dev/null 2>&1 || true
    pkill -9 technical-test-lobster >/dev/null 2>&1 || true
    show_success "Environment ready"
}

# Display welcome message
echo -e "\n${GREEN}=== Lobster Technical Test Setup ===${NC}"
echo -e "This script will set up everything you need to run the application.\n"

# 1. Install Prerequisites
show_progress "Setting up development environment"

# Rust
if ! command_exists rustc || ! command_exists cargo; then
    show_progress "Installing Rust"
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1; then
        source "$HOME/.cargo/env" > /dev/null 2>&1 || show_error "Failed to source Rust environment"
        show_success "Rust installed"
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
        if brew install libpq > /dev/null 2>&1; then
            show_success "PostgreSQL dev libraries installed"
        else
            show_error "Failed to install PostgreSQL dev libraries"
        fi
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! dpkg -l | grep -q libpq-dev; then
        if sudo apt update > /dev/null 2>&1 && sudo apt install -y libpq-dev > /dev/null 2>&1; then
            show_success "PostgreSQL dev libraries installed"
        else
            show_error "Failed to install PostgreSQL dev libraries"
        fi
    fi
fi

# Install development tools
show_progress "Installing development tools"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! command_exists pkg-config; then
        sudo apt install -y pkg-config > /dev/null 2>&1
    fi
    if ! dpkg -l | grep -q libssl-dev; then
        sudo apt install -y libssl-dev > /dev/null 2>&1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! brew list pkg-config >/dev/null 2>&1; then
        brew install pkg-config > /dev/null 2>&1
    fi
    if ! brew list openssl >/dev/null 2>&1; then
        brew install openssl > /dev/null 2>&1
    fi
fi

# Start PostgreSQL
show_progress "Starting database service"
if [[ "$OSTYPE" == "darwin"* ]]; then
    brew services start postgresql > /dev/null 2>&1
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo service postgresql start > /dev/null 2>&1
fi
sleep 2
show_success "Database service running"

# Node.js and npm
if ! command_exists node || ! command_exists npm; then
    install_package nodejs
fi

# Diesel CLI
if ! command_exists diesel; then
    show_progress "Installing Diesel CLI"
    if cargo install diesel_cli --no-default-features --features postgres > /dev/null 2>&1; then
        show_success "Diesel CLI installed"
    else
        show_error "Failed to install Diesel CLI"
    fi
fi

# 2. Set Up the Database
show_progress "Setting up database"
read -p "Enter PostgreSQL username [default: postgres]: " PG_USER
PG_USER=${PG_USER:-postgres}
read -p "Enter PostgreSQL password [press Enter if none]: " -s PG_PASS
echo ""  # Add newline after password input
read -p "Enter database name [default: lobster_db]: " DB_NAME
DB_NAME=${DB_NAME:-lobster_db}

# Set default password if none provided
if [ -z "$PG_PASS" ]; then
    DEFAULT_PASS="default_password"
    if sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$DEFAULT_PASS'" > /dev/null 2>&1; then
        PG_PASS=$DEFAULT_PASS
        echo -e "${GREEN}Default password set for database user${NC}"
    else
        show_error "Failed to set database password. Please run the script again with administrator privileges."
    fi
fi

# Create database if it doesn't exist
if ! PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
    show_progress "Creating database $DB_NAME"
    if PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -c "CREATE DATABASE $DB_NAME;" > /dev/null 2>&1; then
        show_success "Database created"
    else
        show_error "Failed to create database"
    fi
fi

# 3. Install Dependencies
show_progress "Building application"
if ! cargo build --quiet; then
    show_error "Failed to build backend"
fi

# 4. Configure Frontend and Build
if [ -d "frontend" ]; then
    show_progress "Setting up frontend"
    cd frontend
    if npm install > /dev/null 2>&1 && npm run build > /dev/null 2>&1; then
        show_success "Frontend built"
    else
        show_error "Failed to build frontend"
    fi
    cd ..
fi

# 5. Configure .env
show_progress "Configuring environment"
if [ -f ".env" ]; then
    read -p "Existing configuration found. Overwrite? (y/N): " overwrite
    if [[ "$overwrite" != [yY] ]]; then
        show_success "Using existing configuration"
    else
        read -p "Enter Alchemy API key: " ALCHEMY_KEY
        if [ -z "$ALCHEMY_KEY" ]; then
            show_error "Alchemy API key is required"
        fi

        cat > .env << EOL
DATABASE_URL=postgres://$PG_USER${PG_PASS:+:$PG_PASS}@localhost/$DB_NAME
ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_KEY
ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
API_PORT=8080
EOL
        show_success "Configuration updated"
    fi
else
    read -p "Enter Alchemy API key: " ALCHEMY_KEY
    if [ -z "$ALCHEMY_KEY" ]; then
        show_error "Alchemy API key is required"
    fi

    cat > .env << EOL
DATABASE_URL=postgres://$PG_USER${PG_PASS:+:$PG_PASS}@localhost/$DB_NAME
ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_KEY
ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
API_PORT=8080
EOL
    show_success "Configuration created"
fi

# 6. Apply Migrations
show_progress "Setting up database schema"
source .env
if diesel migration run > /dev/null 2>&1; then
    show_success "Database schema ready"
else
    show_error "Failed to set up database schema. Check your PostgreSQL connection."
fi

# 7. Stop any existing processes
stop_processes

# 8. Launch Backend
show_success "Setup completed successfully!"
echo ""
read -p "Launch the application now? (Y/n): " launch
if [[ "$launch" != [nN] ]]; then
    # Trap Ctrl+C to stop all processes
    trap 'echo -e "\n${GREEN}Stopping application...${NC}"; stop_processes; exit 0' INT

    # Launch backend in the foreground
    echo -e "\n${GREEN}Starting application on http://localhost:8080${NC}"
    echo -e "${GREEN}Press Ctrl+C to stop${NC}\n"
    RUST_LOG=info cargo run
else
    echo -e "\n${GREEN}You can start the application manually with:${NC}"
    echo -e "  RUST_LOG=info cargo run"
    echo ""
fi