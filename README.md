# Ethereum ERC-20 Transfer Indexer
Welcome to the **Ethereum ERC-20 Transfer Indexer**, a Rust-based service designed to monitor and index ERC-20 token transfers for the `LobsterToken` on the Ethereum Holesky testnet. This project provides a REST API to query transfer data and includes an optional React-based frontend for users to try out, with all data stored in a PostgreSQL database.

## 🚀 Quick Start
To get started with this project, you can either clone the repository or download it as a ZIP file. Follow these steps:

### Option 1: Clone the Repository
If you have Git installed:
```bash
git clone https://github.com/KyllianGenot/technical-test-lobster.git
cd technical-test-lobster
chmod +x setup.sh
./setup.sh
```

### Option 2: Download the ZIP
If you prefer not to use Git:
1. Go to [https://github.com/KyllianGenot/technical-test-lobster](https://github.com/KyllianGenot/technical-test-lobster).
2. Click the green "Code" button and select "Download ZIP".
3. Extract the ZIP file to a folder of your choice.
4. Open a terminal in that folder and run:
```bash
chmod +x setup.sh
./setup.sh
```

## 💾 PostgreSQL Connection Note
When prompted for PostgreSQL credentials during setup:
- If you don't have a custom PostgreSQL account set up, you can simply press Enter three times to use the default settings:
  - Username: `postgres` (default)
  - Password: (leave empty)
  - Database name: `lobster_db` (default)

This will work in most cases where PostgreSQL was installed with default settings. The script will automatically set up a default password if none is provided.

## 🔧 Setup Details
The setup script will:
- Install all required dependencies (Rust, PostgreSQL, Node.js, etc.)
- Set up your PostgreSQL database
- Configure your environment
- Build the backend and frontend
- Offer to start the application for you

If you stop the application and want to restart it later, simply run:
```bash
RUST_LOG=info cargo run
```

## 📡 Using the Application
After starting the application with `RUST_LOG=info cargo run`, you can:

- **Access the built frontend**: Simply open your browser and navigate to:
  ```
  http://localhost:8080
  ```
  The frontend is automatically served by the backend server - no need to start it separately.

- **Make API calls directly**: 
  ```bash
  # Get all transfers
  curl http://localhost:8080/eth/transfers
  
  # Filter by sender
  curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890"
  
  # Filter by recipient
  curl "http://localhost:8080/eth/transfers?recipient=0xabcdef1234567890abcdef1234567890abcdef12"
  
  # Filter by both
  curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890&recipient=0xabcdef1234567890abcdef1234567890abcdef12"
  ```

- **Repository**: [https://github.com/KyllianGenot/technical-test-lobster](https://github.com/KyllianGenot/technical-test-lobster)
- **Purpose**: A technical demonstration of blockchain indexing, API development, and full-stack integration.

## ✨ Features

- **Real-time Indexing**: Tracks `LobsterToken` `Transfer` events and stores them in a PostgreSQL database.
- **Historical Backfill**: Automatically indexes past transfers starting from the token's deployment block.
- **Optimized Backfill**: Uses binary search to efficiently detect the token's deployment block.
- **REST API**: Provides a `GET /eth/transfers` endpoint with optional sender and recipient filtering.
- **Frontend UI**: An optional, minimalistic interface to view and filter transfer data by sender and recipient.
- **Data Integrity**: Normalizes Ethereum addresses and prevents duplicate transfers.
- **Modular Design**: Organized codebase for maintainability and scalability.

## 🛠️ Manual Setup Instructions

If you prefer to set up the project manually instead of using the setup script, follow these detailed steps:

### Prerequisites

Before you begin, install the following tools:

1. **Rust**  
   - **Why**: Required to compile and run the backend written in Rust.  
   - **How to Install**:  
     - Visit [rust-lang.org](https://www.rust-lang.org/tools/install).  
     - Run the following command in your terminal:  
       ```bash
       curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
       ```  
     - Follow the on-screen instructions to complete the installation.  
     - Verify installation:  
       ```bash
       rustc --version
       cargo --version
       ```

2. **PostgreSQL**  
   - **Why**: Used as the database to store transfer data.  
   - **How to Install**:  
     - Download from [postgresql.org](https://www.postgresql.org/download/) and follow the instructions for your operating system (e.g., Windows, macOS, Linux).  
     - For macOS (via Homebrew):  
       ```bash
       brew install postgresql
       brew services start postgresql
       ```  
     - For Ubuntu:  
       ```bash
       sudo apt update
       sudo apt install postgresql postgresql-contrib
       sudo service postgresql start
       ```  
     - Verify installation:  
       ```bash
       psql --version
       ```

3. **Node.js & npm**  
   - **Why**: Needed to run the optional React frontend.  
   - **How to Install**:  
     - Download from [nodejs.org](https://nodejs.org/) (LTS version recommended).  
     - For macOS (via Homebrew):  
       ```bash
       brew install node
       ```  
     - For Ubuntu:  
       ```bash
       sudo apt update
       sudo apt install nodejs npm
       ```  
     - Verify installation:  
       ```bash
       node --version
       npm --version
       ```

4. **Git**  
   - **Why**: Used to clone the repository.  
   - **How to Install**:  
     - Download from [git-scm.com](https://git-scm.com/).  
     - For macOS (via Homebrew):  
       ```bash
       brew install git
       ```  
     - For Ubuntu:  
       ```bash
       sudo apt update
       sudo apt install git
       ```  
     - Verify installation:  
       ```bash
       git --version
       ```

5. **Diesel CLI**  
   - **Why**: Manages database migrations for PostgreSQL.  
   - **How to Install**:  
     - After installing Rust, run:  
       ```bash
       cargo install diesel_cli --no-default-features --features postgres
       ```  
     - Verify installation:  
       ```bash
       diesel --version
       ```

### Installation

1. **Clone the Repository**  
   ```bash
   git clone https://github.com/KyllianGenot/technical-test-lobster.git
   cd technical-test-lobster
   ```

2. **Set Up the Database**  
   - Step 1: Start PostgreSQL  
     ```bash
     # macOS (Homebrew)
     brew services start postgresql
     # Ubuntu
     sudo service postgresql start
     ```  
   - Step 2: Create a Database  
     ```bash
     psql -U postgres
     ```  
     Inside the `psql` prompt, create a database:  
     ```sql
     CREATE DATABASE lobster_db;
     \q
     ```  
   - Step 3: Verify Database Creation  
     ```bash
     psql -U postgres -c "\l"
     ```  
     Look for `lobster_db` (or your chosen name) in the list.

3. **Install Backend Dependencies**  
   ```bash
   cargo build
   ```

4. **Install Frontend Dependencies**  
   ```bash
   cd frontend
   npm install
   npm run build
   cd ..
   ```

5. **Configuration**  
   - Create a `.env` file in the project root:  
     ```bash
     touch .env
     ```  
   - Add the following lines, replacing placeholders with your PostgreSQL credentials, database name, and Alchemy API key:  
     ```plaintext
     DATABASE_URL=postgres://username:password@localhost/lobster_db
     ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY
     ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
     API_PORT=8080
     ```  
     Notes:  
     - Replace `username` with your PostgreSQL username (default is often `postgres`).  
     - Replace `password` with your PostgreSQL password (leave blank if none, e.g., `postgres://postgres@localhost/lobster_db`).  
     - Replace `lobster_db` with the database name you created.  
     - Replace `YOUR_ALCHEMY_API_KEY` with your actual Alchemy API key (sign up at [alchemy.com](https://www.alchemy.com/) if needed).  

   - After creating your `.env` file, you may need to source it in some environments:  
     ```bash
     source .env
     ```

6. **Apply Database Migrations**  
   ```bash
   diesel migration run
   ```

### 🚀 Running the Project

1. **Start the Backend**  
   Launch the indexer and API server:  
   ```bash
   RUST_LOG=info cargo run
   ```  
   The API will be available at [http://localhost:8080](http://localhost:8080).

2. **Start the Frontend**  
   Navigate to the frontend directory and start the development server:  
   ```bash
   cd frontend
   npm start
   ```  
   The UI will be available at [http://localhost:3000](http://localhost:3000) (or the port specified by Vite).

### Access the Application

- Open your browser to [http://localhost:3000](http://localhost:3000) to view the frontend.  
- Use the API directly at [http://localhost:8080/eth/transfers](http://localhost:8080/eth/transfers).

### ✅ Testing the Project

To verify the project works as expected:

1. **Check Indexing**:  
   After starting the backend, check the logs (`RUST_LOG=info cargo run`) to confirm the indexer detects the LobsterToken deployment block and starts backfilling transfers.

2. **Test the API**:  
   - Retrieve all transfers:  
     ```bash
     curl http://localhost:8080/eth/transfers
     ```  
   - Filter by sender:  
     ```bash
     curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890"
     ```
   - Filter by recipient:  
     ```bash
     curl "http://localhost:8080/eth/transfers?recipient=0xabcdef1234567890abcdef1234567890abcdef12"
     ```
   - Filter by both:
     ```bash
     curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890&recipient=0xabcdef1234567890abcdef1234567890abcdef12"
     ```

3. **View the Frontend**:  
   Open [http://localhost:3000](http://localhost:3000), use the filters to search for transfers by sender or recipient, and verify the table displays the data.

### 🌐 API Documentation

#### GET /eth/transfers

Retrieve a list of LobsterToken transfers, sorted by block number (descending).

**Query Parameters**  
- `sender` (optional): Filter by sender address (e.g., `0x123...`).  
- `recipient` (optional): Filter by recipient address (e.g., `0xabc...`).

**Response Format**  
```json
{
  "token": {
    "decimals": 18,
    "symbol": "LOB"
  },
  "transfers": [
    {
      "id": "123",
      "sender": "0x1234567890123456789012345678901234567890",
      "recipient": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
      "amount": "1000000000000000000",
      "block_number": "123456",
      "tx_hash": "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
  ]
}
```

**Examples**  
- All Transfers:  
  ```bash
  curl http://localhost:8080/eth/transfers
  ```  
- Filter by Sender:  
  ```bash
  curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890"
  ```
- Filter by Recipient:  
  ```bash
  curl "http://localhost:8080/eth/transfers?recipient=0xabcdef1234567890abcdef1234567890abcdef12"
  ```
- Filter by Both:  
  ```bash
  curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890&recipient=0xabcdef1234567890abcdef1234567890abcdef12"
  ```

### 🎨 Frontend Interface

The optional React-based UI includes:  
- Title: "LobsterToken Transfers"  
- Filters: Input fields for Sender and Recipient addresses  
- Table: Displays columns for Sender, Recipient, Amount, Block Number, and Tx Hash  

### 📦 Dependencies

#### Backend (Rust - Cargo.toml)
```toml
[package]
name = "technical-test-lobster"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4"
actix-cors = "0.6.4"
actix-files = "0.6.5"
diesel = { version = "2", features = ["postgres", "r2d2"] }
dotenv = "0.15"
env_logger = "0.11"
hex = "0.4"
log = "0.4"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
web3 = "0.19"
```

#### Frontend (package.json)
```json
{
  "name": "frontend",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "description": "",
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "vite": "^6.2.1"
  },
  "devDependencies": {
    "@types/react": "^19.0.10",
    "@types/react-dom": "^19.0.4",
    "@vitejs/plugin-react": "^4.3.4"
  }
}
```

### ⚠️ Troubleshooting

- **Database Error**: Ensure PostgreSQL is running and your `.env` matches your setup.  
- **API Not Responding**: Verify `RUST_LOG=info cargo run` is active.  
- **Frontend Issues**: Run `npm install` in `frontend/` if dependencies are missing.  
- **Indexer Fails with RPC Error**: If historical data is unavailable (e.g., "data before txNum=X is not available"), use a recent token or an Ethereum node with full archive support.  
- **Indexer Fails with 503 Error**: If you see an error like `[ERROR technical_test_lobster] Indexer failed: code 503` in the logs, this may indicate a temporary issue with the Alchemy API (e.g., server overload or maintenance). This error can occur due to Alchemy's service availability rather than an issue in your code or configuration. Simply restarting the application with `RUST_LOG=info cargo run` may resolve it once the service is back online. If the issue persists, verify your Alchemy API key in `.env` or check Alchemy's status page for outages.

### 📋 Known Limitations

- Historical data availability depends on the Ethereum node provider (e.g., Alchemy). For older tokens, a node with full archive support may be required.  
- The indexer assumes the token follows the ERC-20 standard with standard Transfer events.  

### 📜 License

This project is licensed under the MIT License. See the LICENSE file for details.
