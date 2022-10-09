#!/usr/bin/env bash

# Install puppeteer

# First install chrome or chromium (on arm64)

case "$(dpkg --print-architecture)" in
    arm64)
        apt install -y chromium-browser
    ;;
    *)
        curl -sL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list
        apt update && apt install -y google-chrome-stable
    ;;
esac

npm install -g puppeteer --unsafe-perm=true
