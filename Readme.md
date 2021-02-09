
# Test Clover API

```bash
cp .env.template .env
./import.rb
```

configure http client:

```json
    "rest-client.environmentVariables": {
        "$shared": {
            "version": "v3"
        },
        "clover": {
            "merchant_id": "",
            "token": ""
        },
      }
```
