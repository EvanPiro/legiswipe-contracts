// Address to check for tokens
const address = args[0]

// Date of last check
// const from = args[1]

const config = {
  url: `https://legiswipe.com/.netlify/functions/redeam?address=${address}`
}

const response = await Functions.makeHttpRequest(config)

const price = Math.round(response.data["quantity"])

return Functions.encodeUint256(price)
