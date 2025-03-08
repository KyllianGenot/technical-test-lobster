import React, { useState, useEffect, useCallback } from 'react';
import './App.css';

const ExternalLinkIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path>
    <polyline points="15 3 21 3 21 9"></polyline>
    <line x1="10" y1="14" x2="21" y2="3"></line>
  </svg>
);

const GithubIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const LinkedInIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <rect x="2" y="9" width="4" height="12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <circle cx="4" cy="4" r="2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const EtherscanIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M12 2L4 7v10l8 5 8-5V7l-8-5z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M8 12h8M8 9h8M8 15h8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const App = () => {
  const [transfers, setTransfers] = useState([]);
  const [senderFilter, setSenderFilter] = useState('');
  const [recipientFilter, setRecipientFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const API_URL = import.meta.env.MODE === 'development' ? 'http://localhost:8080' : '';

  const debounce = (func, wait) => {
    let timeout;
    return (...args) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => func(...args), wait);
    };
  };

  const fetchTransfers = useCallback(async (sender = '', recipient = '') => {
    setLoading(true);
    setError(null);
    const url = `${API_URL}/eth/transfers${sender || recipient ? '?' : ''}${sender ? `sender=${encodeURIComponent(sender)}` : ''}${sender && recipient ? '&' : ''}${recipient ? `recipient=${encodeURIComponent(recipient)}` : ''}`;
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
      const data = await response.json();
      setTransfers(data.transfers || []);
    } catch (err) {
      setError(err.message);
      setTransfers([]);
    } finally {
      setLoading(false);
    }
  }, [API_URL]);

  const debouncedFetch = useCallback(
    debounce((sender, recipient) => {
      fetchTransfers(sender, recipient);
    }, 300),
    [fetchTransfers]
  );

  const handleSenderChange = (e) => {
    const value = e.target.value.toLowerCase();
    setSenderFilter(value);
    debouncedFetch(value, recipientFilter);
  };

  const handleRecipientChange = (e) => {
    const value = e.target.value.toLowerCase();
    setRecipientFilter(value);
    debouncedFetch(senderFilter, value);
  };

  const formatAddress = (address) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const formatAmount = (amountStr) => {
    const amount = (BigInt(amountStr) / BigInt(10 ** 18)).toString();
    return new Intl.NumberFormat().format(amount);
  };

  useEffect(() => {
    fetchTransfers();
  }, [fetchTransfers]);

  return (
    <div className="app-container">
      {/* Gradient Background with Blobs */}
      <div className="gradient-background">
        <div className="gradient-overlay"></div>
        <div className="blue-blob blob1"></div>
        <div className="blue-blob blob2"></div>
        <div className="blue-blob blob3"></div>
      </div>
      
      {/* Header */}
      <header className="app-header">
        <div className="header-content">
          <div className="logo">
            <span>LOBSTER |<span className="subtitle">Technical Test</span></span>
          </div>
          <div className="header-actions">
            <a href="https://github.com/KyllianGenot/technical-test-lobster" target="_blank" rel="noopener noreferrer" className="btn btn-outline">
              <GithubIcon /> GitHub
            </a>
            <a href="https://www.linkedin.com/in/kyllian-genot/" target="_blank" rel="noopener noreferrer" className="btn btn-primary">
              <LinkedInIcon /> LinkedIn
            </a>
          </div>
        </div>
      </header>

      <main className="main-content">
        {/* Hero */}
        <section className="hero">
          <h1>LobsterToken Transfers</h1>
          <p>View and filter token transfers on the Holesky testnet with ease.</p>
        </section>

        {/* Filters */}
        <section className="filter-section">
          <div className="filters">
            <div className="filter-group">
              <label htmlFor="sender-filter">Sender Address</label>
              <input
                id="sender-filter"
                type="text"
                placeholder="0x..."
                value={senderFilter}
                onChange={handleSenderChange}
              />
            </div>
            <div className="filter-group">
              <label htmlFor="recipient-filter">Recipient Address</label>
              <input
                id="recipient-filter"
                type="text"
                placeholder="0x..."
                value={recipientFilter}
                onChange={handleRecipientChange}
              />
            </div>
          </div>
        </section>

        {/* Table */}
        <div className="table-container">
          {loading && (
            <div className="status-message loading">
              <div className="loading-spinner"></div>
              Loading transfers
            </div>
          )}
          
          {error && (
            <div className="status-message error">
              Error: {error}
            </div>
          )}
          
          {transfers.length === 0 && !loading && !error && (
            <div className="status-message no-data">
              No transfers found. Try a different filter or check back later.
            </div>
          )}
          
          {transfers.length > 0 && !loading && (
            <table className="transfers-table">
              <thead>
                <tr>
                  <th>Sender</th>
                  <th>Recipient</th>
                  <th>Amount (LOB)</th>
                  <th>Block Number</th>
                  <th>Transaction</th>
                </tr>
              </thead>
              <tbody>
                {transfers.map((transfer) => (
                  <tr key={transfer.id}>
                    <td className="address-cell">{formatAddress(transfer.sender)}</td>
                    <td className="address-cell">{formatAddress(transfer.recipient)}</td>
                    <td className="amount-cell">{formatAmount(transfer.amount)}</td>
                    <td>{transfer.block_number}</td>
                    <td>
                      <a
                        href={`https://holesky.etherscan.io/tx/${transfer.tx_hash}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="tx-link"
                      >
                        {`${transfer.tx_hash.slice(0, 6)}...${transfer.tx_hash.slice(-4)}`}
                        <ExternalLinkIcon />
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Features Section */}
        <section className="features-section">
          <h2>Project Features</h2>
          <div className="feature-cards">
            <div className="feature-card">
              <h3>Token Transfers</h3>
              <p>Track and monitor all token transfers on the Holesky testnet with a clean, intuitive interface.</p>
            </div>
            <div className="feature-card">
              <h3>Filtering System</h3>
              <p>Easily filter transfers by sender or recipient address to quickly find the information you need.</p>
            </div>
            <div className="feature-card">
              <h3>Blockchain Explorer</h3>
              <p>Direct links to transaction details on Etherscan for a seamless exploration experience.</p>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="footer">
        <div className="footer-content">
          <div className="footer-left">
            <div className="footer-logo">
              <span>LOBSTER |<span className="subtitle">Technical Test</span></span>
            </div>
            <p className="footer-tagline">Internship Application 2025</p>
          </div>
          <div className="footer-right">
            <a href="https://github.com/KyllianGenot/technical-test-lobster" target="_blank" rel="noopener noreferrer" className="footer-link">
              <GithubIcon /> GitHub Repository
            </a>
            <a href="https://www.linkedin.com/in/kyllian-genot/" target="_blank" rel="noopener noreferrer" className="footer-link">
              <LinkedInIcon /> Connect on LinkedIn
            </a>
            <a href="https://holesky.etherscan.io/address/0xf794F9B70FB3D9f5a3d5823898c0b2E560bD4348" target="_blank" rel="noopener noreferrer" className="footer-link">
              <EtherscanIcon /> LobsterToken on Etherscan
            </a>
          </div>
        </div>
        <div className="footer-bottom">
          <p>© {new Date().getFullYear()} Kyllian Genot | Lobster Technical Test</p>
        </div>
      </footer>
    </div>
  );
};

export default App;