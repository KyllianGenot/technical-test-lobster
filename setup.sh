#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Exit on error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package with OS-specific logic
install_package() {
    local package=$1
    if ! command_exists "$package"; then
        echo -e "${GREEN}Installing $package...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install "$package" 2>/dev/null || { echo -e "${RED}Failed to install $package with Homebrew.${NC}"; exit 1; }
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if ! command_exists apt; then echo -e "${RED}apt not found, please install $package manually.${NC}"; exit 1; fi
            sudo apt update >/dev/null 2>&1 && sudo apt install -y "$package" >/dev/null 2>&1 || { echo -e "${RED}Failed to install $package with apt.${NC}"; exit 1; }
        else
            echo -e "${RED}Unsupported OS. Please install $package manually.${NC}"
            exit 1
        fi
    fi
}

# Function to stop all related processes
stop_processes() {
    echo -e "${YELLOW}Stopping any existing processes...${NC}"
    if sudo lsof -i :8080 >/dev/null 2>&1; then
        echo -e "${YELLOW}Port 8080 is in use. Stopping processes...${NC}"
        sudo lsof -i :8080 | grep LISTEN | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1 || true
    fi
    pkill -9 cargo >/dev/null 2>&1 || true
    pkill -9 technical-test-lobster >/dev/null 2>&1 || true
    echo -e "${GREEN}All related processes stopped (if any).${NC}"
}

# 1. Install Prerequisites
echo -e "${GREEN}Checking and installing prerequisites...${NC}"

# Rust
if ! command_exists rustc || ! command_exists cargo; then
    echo -e "${GREEN}Installing Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y >/dev/null 2>&1
    source "$HOME/.cargo/env" || { echo -e "${RED}Failed to source Rust environment.${NC}"; exit 1; }
fi

# PostgreSQL
if ! command_exists psql; then
    echo -e "${GREEN}Installing PostgreSQL...${NC}"
    install_package postgresql
fi

# Start PostgreSQL and ensure it's running
echo -e "${GREEN}Starting PostgreSQL service...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if brew services list | grep -q "postgresql.*started"; then
        echo -e "${GREEN}PostgreSQL is already running.${NC}"
    else
        brew services start postgresql >/dev/null 2>&1 || { echo -e "${RED}Failed to start PostgreSQL with brew services.${NC}"; exit 1; }
        sleep 3
        if ! brew services list | grep -q "postgresql.*started"; then
            echo -e "${RED}PostgreSQL failed to start. Please check your installation.${NC}"
            exit 1
        fi
        echo -e "${GREEN}PostgreSQL started successfully.${NC}"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if sudo service postgresql status >/dev/null 2>&1; then
        echo -e "${GREEN}PostgreSQL is already running.${NC}"
    else
        sudo service postgresql start >/dev/null 2>&1 || { echo -e "${RED}Failed to start PostgreSQL with service command.${NC}"; exit 1; }
        sleep 3
        if ! sudo service postgresql status >/dev/null 2>&1; then
            echo -e "${RED}PostgreSQL failed to start. Please check your installation or run 'sudo service postgresql start' manually.${NC}"
            exit 1
        fi
        echo -e "${GREEN}PostgreSQL started successfully.${NC}"
    fi
else
    echo -e "${RED}Unsupported OS for PostgreSQL startup. Please start PostgreSQL manually.${NC}"
    exit 1
fi

# Node.js and npm
if ! command_exists node || ! command_exists npm; then
    install_package nodejs
fi

# Git (optional since repo is already cloned)
if ! command_exists git; then
    install_package git
fi

# Diesel CLI
if ! command_exists diesel; then
    cargo install diesel_cli --no-default-features --features postgres >/dev/null 2>&1
fi

# Verify all tools
for cmd in rustc cargo psql node npm git diesel; do
    if ! command_exists "$cmd"; then
        echo -e "${RED}$cmd installation verification failed.${NC}"
        exit 1
    fi
done

# 2. Set Up the Database
echo -e "${GREEN}Setting up the database...${NC}"
read -p "Enter PostgreSQL username [default: postgres]: " PG_USER
PG_USER=${PG_USER:-postgres}
read -p "Enter PostgreSQL password [press Enter if none]: " PG_PASS
read -p "Enter database name [default: lobster_db]: " DB_NAME
DB_NAME=${DB_NAME:-lobster_db}

# Verify PostgreSQL is running and accessible
echo -e "${GREEN}Testing PostgreSQL connection...${NC}"
# Try local socket connection first (no password for fresh install)
if ! psql -U "$PG_USER" -lqt >/dev/null 2>&1; then
    echo -e "${YELLOW}Local socket connection failed. Trying with password and localhost...${NC}"
    if ! PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -lqt >/dev/null 2>&1; then
        echo -e "${RED}Cannot connect to PostgreSQL. This may be due to a fresh install with no password or misconfiguration.${NC}"
        echo -e "${YELLOW}Please run the following commands to set up PostgreSQL manually:${NC}"
        echo -e "${GREEN}sudo -u postgres psql${NC}"
        echo -e "${GREEN}ALTER USER postgres WITH PASSWORD 'your_password';${NC}"
        echo -e "${GREEN}\\q${NC}"
        echo -e "${GREEN}Then rerun the script and enter 'your_password' when prompted.${NC}"
        exit 1
    fi
fi

# Check if the specific database exists by trying to connect to it
echo -e "${GREEN}Checking if database $DB_NAME exists...${NC}"
if PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
    echo -e "${GREEN}Database $DB_NAME already exists.${NC}"
else
    echo -e "${GREEN}Creating database $DB_NAME...${NC}"
    PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -c "CREATE DATABASE $DB_NAME;" >/dev/null 2>&1 || { echo -e "${RED}Failed to create database $DB_NAME.${NC}"; exit 1; }
    if ! PGPASSWORD="$PG_PASS" psql -U "$PG_USER" -h localhost -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
        echo -e "${RED}Failed to verify database $DB_NAME after creation.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Database $DB_NAME created successfully.${NC}"
fi

# 3. Install Dependencies
echo -e "${GREEN}Installing dependencies...${NC}"
cargo build --quiet || { echo -e "${RED}Failed to build backend.${NC}"; exit 1; }

# 4. Configure Frontend and Build
echo -e "${GREEN}Setting up frontend...${NC}"
if [ -d "frontend" ]; then
    cd frontend
    if ! command_exists npm; then
        echo -e "${RED}npm is required to build the frontend. Please install Node.js and npm.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Installing frontend dependencies...${NC}"
    npm install >/dev/null 2>&1 || { echo -e "${RED}Failed to install frontend dependencies.${NC}"; exit 1; }
    echo -e "${GREEN}Building frontend...${NC}"
    npm run build >/dev/null 2>&1 || { echo -e "${RED}Failed to build frontend.${NC}"; exit 1; }
    cd ..
    echo -e "${GREEN}Frontend built successfully.${NC}"
else
    echo -e "${YELLOW}Frontend directory not found. Skipping frontend setup.${NC}"
fi

# 5. Configure .env
echo -e "${GREEN}Configuring .env file...${NC}"
if [ -f ".env" ]; then
    read -p "Existing .env found. Overwrite? (y/N): " overwrite
    if [[ "$overwrite" != [yY] ]]; then
        echo -e "${GREEN}Keeping existing .env file.${NC}"
    else
        # Overwrite the .env file
        read -p "Enter Alchemy API key [required]: " ALCHEMY_KEY
        if [ -z "$ALCHEMY_KEY" ]; then
            echo -e "${RED}Alchemy API key is required.${NC}"
            exit 1
        fi

        cat > .env << EOL
DATABASE_URL=postgres://$PG_USER${PG_PASS:+:$PG_PASS}@localhost/$DB_NAME
ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_KEY
ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
API_PORT=8080
EOL
        echo -e "${GREEN}.env file overwritten successfully.${NC}"
    fi
else
    # Create a new .env file
    read -p "Enter Alchemy API key [required]: " ALCHEMY_KEY
    if [ -z "$ALCHEMY_KEY" ]; then
        echo -e "${RED}Alchemy API key is required.${NC}"
        exit 1
    fi

    cat > .env << EOL
DATABASE_URL=postgres://$PG_USER${PG_PASS:+:$PG_PASS}@localhost/$DB_NAME
ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_KEY
ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
API_PORT=8080
EOL
    echo -e "${GREEN}.env file created successfully.${NC}"
fi

# 6. Apply Migrations
echo -e "${GREEN}Applying database migrations...${NC}"
source .env
diesel migration run || { echo -e "${RED}Failed to apply migrations. Check PostgreSQL connection and DATABASE_URL in .env.${NC}"; exit 1; }
echo -e "${GREEN}Migrations applied successfully.${NC}"

# 7. Stop any existing processes
stop_processes

# 8. Launch Backend
echo -e "${GREEN}Setup completed successfully!${NC}"
read -p "Do you want to launch the backend (RUST_LOG=info cargo run)? (y/N): " launch
if [[ "$launch" == [yY] ]]; then
    # Trap Ctrl+C to stop all processes
    trap 'echo -e "${YELLOW}Stopping all processes...${NC}"; stop_processes; exit 0' INT

    # Launch backend in the foreground
    echo -e "${GREEN}Launching backend in the foreground (use Ctrl+C to stop)...${NC}"
    RUST_LOG=info cargo run
else
    echo -e "${GREEN}You can start the backend manually with 'RUST_LOG=info cargo run'.${NC}"
fi