#!/usr/bin/env node

// @(#) render a page that uses Javascript

module.paths.push('/usr/lib/node_modules')

const puppeteer = require('puppeteer');

const target = process.argv[2] || 'http://apache.org/';

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  await page.goto(target);
  let html = await page.content();
  console.log(html)
  await browser.close();
})();
