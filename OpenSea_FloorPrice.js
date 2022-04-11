import fetch from "node-fetch"; // issue here

const options = { method: 'GET' };

fetch('https://testnets-api.opensea.io/api/v1/asset_contract/0x3F029AB70b36848e7D9b615FE70de3367dBF8821', options)
    .then(response => response.json())
    .then(response => console.log(response))
    .catch(err => console.error(err));

// THE ABOVE IS NOT CORRECT: THE STEPS ARE AS FOLLOWS

/* Step 1) Use OpenSea "Retrieving a single contract - Testnets" for a specific contract address
 *          - select the slug from the json response: response.json()['collection']['slug']
 * Step 2) Use OpenSea "Retrieving collection stats - Testnets" for the found slug
 *          - have to add the slug into the URL
 *          - select floor price: response.json()['stats']['floor_price']
 */