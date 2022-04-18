import puppeteer from 'puppeteer-extra';
import AdblockerPlugin from 'puppeteer-extra-plugin-adblocker';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';

import CollectionConfig from './../config/CollectionConfig';

puppeteer.use(StealthPlugin());
puppeteer.use(AdblockerPlugin({ blockTrackers: true }));

const [startArg, endArg] = process.argv.slice(2);
const CONTRACT_ADDRESS = CollectionConfig.contractAddress;
const CHAIN = 'rinkeby'; // PIN: TODO: Read this from config

const START = parseInt(startArg);
const END = parseInt(endArg);
if (!START || !END) {
  throw new Error(
    '\x1b[31merror\x1b[0m ' +
      'Please provide a start and end edition number. Example: npm run refresh_os 1 10 or yarn refresh_os 1 10'
  );
}

const COLLECTION_BASE_URL =
  CHAIN.toLowerCase() === 'rinkeby' ? `https://testnets.opensea.io/assets` : 'https://opensea.io/assets/matic';

async function main() {
  const notFound = [];
  const errors = [];
  const browser = await puppeteer.launch({
    headless: false,
  });

  console.log(`Beginning OpenSea Refresh from ${START} to ${END}`);
  const page = await browser.newPage();

  for (let i = START; i <= END; i++) {
    try {
      console.log(`Refreshing Edition: ${i}`);

      const url = `${COLLECTION_BASE_URL}/${CONTRACT_ADDRESS}/${i}`;

      await page.goto(url);

      await page.waitForSelector('button>div>i[value="refresh"]');
      const pageTitle = await page.$$eval('title', title => title.map(title => title.textContent));
      if (pageTitle[0]!.includes('Not Found')) {
        console.log(`Edition ${i} not found!`);
        notFound.push(i);
      }

      await page.click('button>div>i[value="refresh"]');
      await page.waitForTimeout(5000);

      console.log(`Refreshed Edition: ${i}`);
    } catch (error) {
      console.log(`Error refreshing edition ${i}: ${error}`);
      errors.push(i);
    }
  }

  await browser.close();

  if (notFound.length > 0 || errors.length > 0) {
    console.log(`Not Found: ${notFound}`);
    console.log(`Errors: ${errors}`);
  }
  console.log(`Finished OpenSea Refresh`);
}

main();
