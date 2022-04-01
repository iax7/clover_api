# Usage

You will need to install [REST Client for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
Configure VS Code settings to use http files in this folder.

Configure the environment variables and select it (REST CLient Environment):
![image](https://user-images.githubusercontent.com/6983510/161328698-5ee11421-4f6b-4220-81fa-4c8dacc2d8e7.png)

```jsonc
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
