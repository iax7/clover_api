# Usage

You will need to install [REST Client for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
Configure VS Code settings to use http files in this folder.

Configure the environment variables and select it (REST CLient Environment):

```json
    "rest-client.environmentVariables": {
        "$shared": {
            // BigCommerce (bigcommerce.http)
            "version": "v3",
            "store_hash": "",
            "client_id": "",
            "access_token": "",
        },
        "dev": {
            // Square (sq.http)
            "sq_token": "",
            "sq_location_id": "",
            // Clover (clover.http)
            "cl_merchant_id": "",
            "cl_token": ""
        },
```
