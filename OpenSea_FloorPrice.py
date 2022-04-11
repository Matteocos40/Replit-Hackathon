import requests

address = '0x3F029AB70b36848e7D9b615FE70de3367dBF8821'
url = "https://testnets-api.opensea.io/api/v1/asset_contract/"+address

response = requests.request("GET", url)
#print(response.json())
slug = response.json()['collection']['slug']

url_floor = "https://testnets-api.opensea.io/api/v1/collection/"+slug +"/stats"

response_floor = requests.request("GET", url_floor)

print('floor price:', response_floor.json()['stats']['floor_price'])
