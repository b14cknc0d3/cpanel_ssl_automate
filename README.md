# SSL Automation for cPanel

**One-click SSL certificate automation for cPanel shared hosting.** Free, automated, and no root access required.

## ⚡ Quick Install

Run this single command on your cPanel server (via SSH):

```bash
curl -fsSL https://raw.githubusercontent.com/b14cknc0d3/cpanel_ssl_automate/main/install.sh | bash
```

That's it! The script will:
- ✓ Ask for your domain and email
- ✓ Install acme.sh (Let's Encrypt client)
- ✓ Obtain SSL certificate automatically
- ✓ Deploy to cPanel
- ✓ Enable HTTPS redirect
- ✓ Setup auto-renewal

## 🎯 Features

- **One-Click Installation**: Single command does everything
- **No Root Required**: Works on shared hosting
- **Auto-Detection**: Finds username, webroot, hostname automatically
- **HTTPS Redirect**: Automatically forces HTTPS via .htaccess
- **Auto-Renewal**: Sets up cron job for automatic renewal
- **Smart Cleanup**: Removes broken certificate entries
- **Generic & Reusable**: Works with any domain and cPanel host
- **Open Source**: Free to use and modify

## 📋 Requirements

- cPanel shared hosting with SSH access
- Domain pointed to your hosting
- SSH access (check with your hosting provider)
- That's it!

## 🚀 Usage

### First Time Setup

1. SSH into your cPanel server:
```bash
ssh username@your-server.com -p 21098
```

2. Run the installer:
```bash
curl -fsSL https://raw.githubusercontent.com/b14cknc0d3/cpanel_ssl_automate/main/install.sh | bash
```

3. Answer the prompts:
   - Email address (for SSL notifications)
   - Your domain name
   - Include www subdomain? (Y/n)

The script auto-detects everything else!

### No SSH? Use cPanel Terminal

If you don't have SSH access, you can use cPanel's built-in Terminal:

1. Log into cPanel
2. Go to **Advanced** → **Terminal**
3. Run the installer:
```bash
curl -fsSL https://raw.githubusercontent.com/b14cknc0d3/cpanel_ssl_automate/main/install.sh | bash
```

## 🔧 What Gets Installed

```
~/.ssl-automation.config     # Your saved configuration
~/.acme.sh/                  # Let's Encrypt ACME client
~/ssl-automation.log         # Installation and renewal logs
~/public_html/.htaccess      # HTTPS redirect (modified)
```

Plus a daily cron job for automatic certificate renewal.

## 🔄 Re-running Installation

To reconfigure or install for a different domain:

```bash
# The script will ask if you want to use existing config
curl -fsSL https://raw.githubusercontent.com/b14cknc0d3/cpanel_ssl_automate/main/install.sh | bash
```

To start completely fresh:

```bash
rm -f ~/.ssl-automation.config
curl -fsSL https://raw.githubusercontent.com/b14cknc0d3/cpanel_ssl_automate/main/install.sh | bash
```

## 🌟 Supported Hosting Providers

Tested with:
- Namecheap Shared Hosting
- Bluehost
- HostGator
- SiteGround
- Any cPanel-based hosting with SSH

## 🤝 Contributing

Issues and pull requests welcome!

## 📜 License

MIT License - Free to use, modify, and distribute

## 🙏 Credits

Built with:
- [acme.sh](https://github.com/acmesh-official/acme.sh) - ACME Shell script
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

---

**Made with ❤️ for easy SSL automation**

### Star this repo if it helped you! ⭐
