#!/bin/bash
# =============================================================
# Cockpit Dashboard — Automated Setup Script
# =============================================================
# Run this AFTER cloning the repo and switching to your branch.
#
# Usage:
#   cd cockpit
#   bash docs/setup.sh
# =============================================================

set -e

echo ""
echo "========================================"
echo "  Cockpit Dashboard — Setup Script"
echo "========================================"
echo ""

# --- Check prerequisites ---
echo "Checking prerequisites..."
echo ""

if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed."
    echo "  -> Download it from https://nodejs.org (click the LTS button)"
    echo "  -> Then run this script again."
    exit 1
fi
echo "  Node.js: $(node --version)"

if ! command -v npm &> /dev/null; then
    echo "ERROR: npm is not installed."
    echo "  -> It should come with Node.js. Try reinstalling Node."
    exit 1
fi
echo "  npm:     v$(npm --version)"

if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed."
    echo "  -> Mac: run 'xcode-select --install'"
    echo "  -> Windows: download from https://git-scm.com"
    exit 1
fi
echo "  git:     $(git --version)"
echo ""

# --- Check for .env file ---
if [ ! -f .env ]; then
    echo "WARNING: No .env file found!"
    echo "  -> Get the .env contents from Aaron"
    echo "  -> Create a file called '.env' in this folder"
    echo "  -> Paste the contents and save"
    echo ""
    echo "Once you've created the .env file, run this script again."
    exit 1
fi
echo ".env file found."
echo ""

# --- Install dependencies ---
echo "Installing dependencies (this may take a minute)..."
npm install
echo ""
echo "Dependencies installed."
echo ""

# --- Generate Prisma client ---
echo "Generating database client..."
npx prisma generate
echo ""

# --- Done ---
echo "========================================"
echo "  Setup complete!"
echo "========================================"
echo ""
echo "To start the dashboard, run:"
echo ""
echo "  npm run dev"
echo ""
echo "Then open http://localhost:3000 in your browser."
echo ""
echo "To upload Metricool reports, go to:"
echo "  http://localhost:3000/admin/uploads"
echo ""
