#!/usr/bin/env node

// @(#) extract non-ASF links when loading a page

module.paths.push('/usr/lib/node_modules')

const puppeteer = require('puppeteer');

const target = process.argv[2] || 'https://apache.org/';
const inithost = new URL(target).host;

const option = process.argv[3] || '';

// TODO: this list is not complete
function isASFhost(host) {
  return host == '' || 
         host == 'apache.org' ||
         host == 'apachecon.com' ||
         host == 'openoffice.org' ||
         host.endsWith('.apache.org') ||
         host.endsWith('.openoffice.org') ||
         host.endsWith('.apachecon.com');
}
if (!isASFhost(inithost)) {
  throw new Error("Only ASF hosts are supported - saw " + inithost);
}

function getHost(url) {
  return new URL(url).host;
}

(async () => {
  // new fails with:
  // Error: Failed to launch the browser process!
  // chrome_crashpad_handler: --database is required
  // Need executablePath on later versions of Ubuntu
  const browser = await puppeteer.launch({headless: "old", executablePath: '/opt/google/chrome/chrome'});
  const page = await browser.newPage();
  await page.setRequestInterception(true);
  // capture CSP messages
  page.on('console', message =>
      console.log(`${message.type().toUpperCase()} ${message.text()}`))
  page.on('request', (interceptedRequest) => {
    // already handled?
    if (interceptedRequest.isInterceptResolutionHandled()) return;

    const url = interceptedRequest.url();
    if (url == target) {
      // must allow this through
      interceptedRequest.continue();
    } else {
      let host = new URL(url).host
      if (!isASFhost(host)) {
        // don't visit non-ASF hosts unless requested
        if (option == 'all') {
          console.log(url);
          interceptedRequest.continue();
        } else if (option == 'allref') {
          ini = interceptedRequest.initiator();
          let iniurl = ini.url;
          if (!iniurl && ini.stack) {
            iniurl = ini.stack.callFrames[0].url;
          }
          if (iniurl && inithost != getHost(iniurl)) { // second level
            console.log(url + ' <= ' + iniurl);
          } else {
            console.log(url);
          }
          interceptedRequest.continue();
        } else {
          if (option == 'showurl') {
            console.log(url);
          } else {
            console.log(host);
          }
          interceptedRequest.abort();
        }
      } else {
        // Need to visit at least an initial redirect
        interceptedRequest.continue();
      }
    }
  });
  let result = await page.goto(target);
  let status = result.status();
  if (status && status != 200) {
    let url = result.url();
    let error = `Status ${status} for ${url}`;
    throw new Error(error);
  }
  await browser.close();
})();
