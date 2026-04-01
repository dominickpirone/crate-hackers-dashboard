# Cockpit Dashboard — New Team Member Setup Guide

**Welcome to Crate Hackers!** This guide will get you up and running with our
company metrics dashboard ("Cockpit") in about 10 minutes. No coding experience
needed.

---

## What is Cockpit?

Cockpit is our Bloomberg-style company metrics dashboard. It shows:

- **Customer metrics** — 46K+ customers, growth trends
- **Revenue** — MRR, ARR, churn rates
- **Conversion funnel** — from visitor to paying customer
- **Social media stats** — auto-updated from Metricool PDF reports

It's built with **Next.js**, **Prisma**, and **Supabase** (don't worry about
what those are — just know they're the tools that make it work).

---

## Before You Start

You need three things installed on your computer. Open **Terminal** (Mac) or
**Command Prompt / PowerShell** (Windows) and check each one:

### 1. Check for Git

```bash
git --version
```

You should see something like `git version 2.43.0`. If you get an error:

- **Mac:** Open Terminal and run: `xcode-select --install`
- **Windows:** Download from https://git-scm.com/download/win — use all the
  default settings during install

### 2. Check for Node.js

```bash
node --version
```

You should see something like `v22.22.0`. If you get an error:

- **Mac or Windows:** Go to https://nodejs.org — click the big green
  **"LTS"** button, download, and install with all the defaults

### 3. Check for npm (comes with Node.js)

```bash
npm --version
```

You should see something like `10.9.4`. If Node.js is installed, npm should
be too.

---

## Setup Steps (One Time Only)

### Step 1: Clone the repo

This downloads a copy of the project to your computer.

```bash
cd ~/Desktop
git clone https://github.com/thecratehackers/cockpit.git
cd cockpit
```

You'll now have a folder called `cockpit` on your Desktop.

### Step 2: Switch to your branch

Think of a "branch" like your own workspace where you can make changes without
affecting anyone else's work.

```bash
git checkout dom/dev
```

If the branch doesn't exist yet:

```bash
git checkout -b dom/dev
```

### Step 3: Set up your .env file

The `.env` file contains passwords and secret keys the app needs to connect
to our database. **Never share this file or commit it to git.**

Ask Aaron for the `.env` contents, then:

```bash
# Create the file (Mac/Linux)
touch .env

# Or on Windows PowerShell
New-Item .env
```

Open the `.env` file in any text editor (TextEdit, Notepad, VS Code) and paste
in the contents Aaron gives you. Save and close.

### Step 4: Install dependencies

This downloads all the code packages the app needs.

```bash
npm install
```

This might take a minute. You'll see a lot of text scrolling — that's normal.

### Step 5: Generate the database client

```bash
npx prisma generate
```

### Step 6: Start the app

```bash
npm run dev
```

You should see something like:

```
▲ Next.js 14.x.x
- Local: http://localhost:3000
```

### Step 7: Open the dashboard

Open your web browser and go to: **http://localhost:3000**

You should see the Cockpit dashboard!

---

## Daily Workflow

### Starting your day

1. Open Terminal
2. Navigate to the project:
   ```bash
   cd ~/Desktop/cockpit
   ```
3. Pull the latest changes:
   ```bash
   git pull origin dom/dev
   ```
4. Start the app:
   ```bash
   npm run dev
   ```
5. Open http://localhost:3000

### Uploading Metricool reports

1. Go to **http://localhost:3000/admin/uploads**
2. Drag and drop your Metricool PDF report
3. The dashboard will auto-update with the new social media numbers

### Making changes (with Claude's help)

When you want to change something on the dashboard:

1. Describe what you want in plain English to Claude
2. Claude will make the code changes for you
3. When you're done, ask Claude to commit and push your changes

### Ending your day

Ask Claude to:
> "Commit my changes and push to dom/dev"

Or do it manually:
```bash
git add .
git commit -m "Description of what changed"
git push -u origin dom/dev
```

---

## Important Rules

| Rule | Why |
|------|-----|
| **Always work on `dom/dev`** | Never push to `main` — that's the live version |
| **Never commit the `.env` file** | It has passwords and secret keys |
| **Pull before you start working** | Gets you the latest changes from the team |
| **Ask Claude for help** | Describe changes in plain English — no coding needed |

---

## Common Problems

### "Command not found: node"
Node.js isn't installed. See the "Before You Start" section above.

### "npm install" shows errors
Try deleting the `node_modules` folder and `package-lock.json`, then run
`npm install` again:
```bash
rm -rf node_modules package-lock.json
npm install
```

### "Port 3000 is already in use"
Something else is running on port 3000. Either close it, or start the app on
a different port:
```bash
npx next dev -p 3001
```
Then open http://localhost:3001

### The dashboard looks broken or shows errors
1. Stop the server (press `Ctrl + C` in Terminal)
2. Run `npm install` again
3. Run `npx prisma generate` again
4. Start the server with `npm run dev`

### "Permission denied" errors
On Mac/Linux, try adding `sudo` before the command:
```bash
sudo npm install
```

---

## Quick Reference Card

| What | Command |
|------|---------|
| Start the app | `npm run dev` |
| Stop the app | `Ctrl + C` in Terminal |
| Pull latest changes | `git pull origin dom/dev` |
| Check your branch | `git branch` |
| Switch to your branch | `git checkout dom/dev` |
| Upload reports | http://localhost:3000/admin/uploads |
| View dashboard | http://localhost:3000 |

---

*Last updated: April 2026. Questions? Ask Aaron or message in Slack.*
