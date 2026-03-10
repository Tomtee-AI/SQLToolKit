# SQLToolKit
SQL Server DBA Toolkit: A collection of scripts and tools for database administration
# SQL Server DBA Toolkit

**A collection of powerful, battle-tested T-SQL scripts, utilities, and tools to make SQL Server database administration faster, safer, and more efficient.**

![SQL Server Logo](https://img.shields.io/badge/SQL%20Server-2016%2B-blue?logo=microsoft-sql-server&logoColor=white)
![License](https://img.shields.io/github/license/Tomtee-AI/SQLToolkit?style=flat-square)
![Stars](https://img.shields.io/github/stars/Tomtee-AI/SQLToolkit?style=social)
![Forks](https://img.shields.io/github/forks/Tomtee-AI/SQLToolkit?style=social)

## ✨ Features

- **Performance troubleshooting** — Wait stats, query store analysis, index recommendations, blocking detection
- **Health checks & monitoring** — Instance & database configuration audits, backup verification, disk space alerts
- **Maintenance automation** — Index & statistics maintenance, integrity checks, log file management
- **Security & compliance** — Permission audits, orphaned users cleanup, login & role reporting
- **Disaster recovery helpers** — Tail-log backup scripts, restore sequence generators
- **Utility scripts** — Date dimension generator, number table creator, string splitters/aggregators
- **Compatible** with SQL Server 2016 and newer (some scripts support 2012/2014 with minor adjustments)

## 📋 Table of Contents

- [Installation](#installation)
- [Quick Start / Usage](#quick-start--usage)
- [Scripts Overview](#scripts-overview)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Contact & Feedback](#contact--feedback)

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/Tomtee-AI/SQLToolKit.git

## Quick Start / Usage

Example: Check current blocking sessions and wait stats
SQL-- 1. Navigate to the scripts folder
-- 2. Open: Troubleshooting\Who is blocking whom - detailed.sql

-- Customize variables if needed (most scripts have them at the top)
DECLARE @ShowFullSQL bit = 1;
DECLARE @ThresholdSeconds int = 5;

-- Run the script
EXEC dbo.usp_WhoIsBlocking @ShowFullSQL = @ShowFullSQL, @ThresholdSeconds = @ThresholdSeconds;
Another example: Run a full instance health check
SQL-- Open: Health-Check\SQL Server Instance Health Check - comprehensive.sql
-- Review parameters, then execute
See the Scripts Overview section below for more examples.

## Scripts  Overview
## Contributing
## License

## Acknowledgments
Inspired by / built upon community resources such as:

Ola Hallengren's Maintenance Solution
Brent Ozar's sp_Blitz suite
Erik Darling's Darling Data scripts
Various SQL Server Central / Stack Overflow gems
## Contact & Feedback
