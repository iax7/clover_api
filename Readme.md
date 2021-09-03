
# Test Clover API
> Test Clover API project to create items, categories and orders.

[![Ruby][ruby-badge]][ruby-url]

##Usage

```bash
# Create your .env file from template
cp .env.template .env

# Run upload script
./upload.rb
```

Configure http client in VS Code:

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

[ruby-badge]: https://img.shields.io/badge/ruby-3.0.2-blue?style=flat&logo=ruby&logoColor=CC342D&labelColor=white
[ruby-url]: https://www.ruby-lang.org/en/