// Address to check for tokens
const base = args[0]

// Date of last check
const quote = args[1]

const config = {
  url: 'https://legiswipe.com/.netlify/functions/redeam'
}

const response = await Functions.makeHttpRequest(config)

const price = Math.round(response.data["quantity"])

return Functions.encodeUint256(price)
