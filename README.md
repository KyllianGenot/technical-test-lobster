# Ethereum ERC-20 Transfer Indexer

Welcome to the **Ethereum ERC-20 Transfer Indexer**, a Rust-based service designed to monitor and index ERC-20 token transfers for the `LobsterToken` on the Ethereum Holesky testnet. This project provides a REST API to query transfer data and includes an optional React-based frontend for users to try out, with all data stored in a PostgreSQL database.

- **Repository**: [https://github.com/KyllianGenot/technical-test-lobster](https://github.com/KyllianGenot/technical-test-lobster)
- **Purpose**: A technical demonstration of blockchain indexing, API development, and full-stack integration.

## ✨ Features

- **Real-time Indexing**: Tracks `LobsterToken` `Transfer` events and stores them in a PostgreSQL database.
- **Historical Backfill**: Indexes past transfers starting from deployment block `3447859`.
- **REST API**: Provides a `GET /eth/transfers` endpoint with optional sender and recipient filtering.
- **Frontend UI**: An optional, minimalistic interface to view and filter transfer data by sender and recipient.
- **Data Integrity**: Normalizes Ethereum addresses and prevents duplicate transfers.
- **Modular Design**: Organized codebase for maintainability and scalability.

## 🛠️ Setup Instructions

Follow these steps to get the project running locally. You'll need to install prerequisites, set up your PostgreSQL database, and configure your `.env` file.

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
   - **Step 1**: Start PostgreSQL
     ```bash
     # macOS (Homebrew)
     brew services start postgresql
     # Ubuntu
     sudo service postgresql start
     ```
   - **Step 2**: Create a Database
     ```bash
     psql -U postgres
     ```
     Inside the psql prompt, create a database:
     ```sql
     CREATE DATABASE lobster_db;
     \q
     ```
   - **Step 3**: Verify Database Creation
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

### Configuration

You must create a `.env` file with your `DATABASE_URL`, `ETHEREUM_NODE_URL`, `ETHEREUM_TOKEN_ADDRESS` AND `API_PORT`.

1. **Set Up Environment Variables**  
   Create a `.env` file in the project root:
   ```bash
   touch .env
   ```
   Add the following lines, replacing placeholders with your PostgreSQL credentials, database name and Alchemy API key:
   ```
   DATABASE_URL=postgres://username:password@localhost/lobster_db
   ETHEREUM_NODE_URL=https://eth-holesky.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY
   ETHEREUM_TOKEN_ADDRESS=0xf794F9B70FB3D9F5a3d5823898c0b2E560bD4348
   API_PORT=8080
   ```
   **Notes**:
   - Replace `username` with your PostgreSQL username (default is often `postgres`).
   - Replace `password` with your PostgreSQL password (leave blank if none, e.g., `postgres://postgres@localhost/lobster_db`).
   - Replace `lobster_db` with the database name you created.
   - Replace `YOUR_ALCHEMY_API_KEY` with your actual Alchemy API key (sign up at [alchemy.com](https://www.alchemy.com/) if needed).

   After creating your `.env` file, you may need to source it in some environments:
   ```bash
   source .env
   ```
   This ensures the environment variables are loaded into your current shell session.

2. **Apply Database Migrations**  
   Run this command to set up the database schema:
   ```bash
   diesel migration run
   ```
   If successful, you'll see output indicating migrations were applied.

## 🚀 Running the Project

1. **Start the Backend**  
   Launch the indexer and API server:
   ```bash
   RUST_LOG=info cargo run
   ```
   The API will be available at http://localhost:8080.

2. **Start the Frontend**  
   Navigate to the frontend directory and start the development server:
   ```bash
   cd frontend
   npm start
   ```
   The UI will be available at http://localhost:3000 (or the port specified by Vite).

3. **Access the Application**  
   - Open your browser to http://localhost:3000 to view the frontend.
   - Use the API directly at http://localhost:8080/eth/transfers.

## 🌐 API Documentation

### GET /eth/transfers

Retrieve a list of LobsterToken transfers, sorted by block number (descending).

#### Query Parameters
- `sender` (optional): Filter by sender address (e.g., 0x123...).
- `recipient` (optional): Filter by recipient address (e.g., 0xabc...).

#### Response Format
```json
{
  "token": {
    "decimals": 18,
    "symbol": "LOB"
  },
  "transfers": [
    {
      "sender": "0x1234567890123456789012345678901234567890",
      "recipient": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
      "amount": "1000000000000000000",
      "block_number": "123456",
      "tx_hash": "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    }
  ]
}
```

#### Examples
- **All Transfers**:
  ```bash
  curl http://localhost:8080/eth/transfers
  ```
- **Filter by Sender**:
  ```bash
  curl "http://localhost:8080/eth/transfers?sender=0x1234567890123456789012345678901234567890"
  ```

## 🎨 Frontend Interface

The optional React-based UI includes:
- **Title**: "LobsterToken Transfers"
- **Filters**: Input fields for Sender and Recipient addresses
- **Table**: Displays columns for Sender, Recipient, Amount, Block Number, and Tx Hash

![Frontend Screenshot](./frontend.png)

## 📦 Dependencies

### Backend (Rust - Cargo.toml)
- `actix-web = "4"`: REST API framework
- `actix-cors = "0.6.4"`: CORS support for the API
- `actix-files = "0.6.5"`: Serving static files
- `diesel = { version = "2", features = ["postgres", "r2d2"] }`: PostgreSQL ORM with connection pooling
- `dotenv = "0.15"`: Loading environment variables from .env files
- `env_logger = "0.11"`: Environment-based logging configuration
- `hex = "0.4"`: Hexadecimal encoding/decoding
- `log = "0.4"`: Logging framework
- `serde = { version = "1", features = ["derive"] }`: Serialization and deserialization
- `serde_json = "1"`: JSON handling
- `tokio = { version = "1", features = ["full"] }`: Async runtime
- `web3 = "0.19"`: Ethereum blockchain interaction

### Frontend (package.json)
- **Dependencies**:
  - `react: "^19.0.0"` - UI library
  - `react-dom: "^19.0.0"` - React rendering for the DOM
  - `vite: "^6.2.1"` - Build tool and development server
- **Dev Dependencies**:
  - `@types/react: "^19.0.10"` - TypeScript types for React
  - `@types/react-dom: "^19.0.4"` - TypeScript types for React DOM
  - `@vitejs/plugin-react: "^4.3.4"` - Vite plugin for React support

## ⚠️ Troubleshooting

- **Database Error**: Ensure PostgreSQL is running and your `.env` matches your setup.
- **API Not Responding**: Verify `RUST_LOG=info cargo run` is active.
- **Frontend Issues**: Run `npm install` in `frontend/` if dependencies are missing.

## 📜 License

This project is licensed under the MIT License. See the LICENSE file for details.