# Represent API: CSV Proxy

[Represent](https://represent.opennorth.ca/) is the open database of Canadian elected officials and electoral districts. It provides a [REST API](https://represent.opennorth.ca/api/) to boundary, representative, and postcode resources.

This repository proxies Google Sheets with elected officials' contact information and reformats the data for import into Represent.

**If this repository requires maintenance, it should be merged into [scrapers-ca](https://github.com/opencivicdata/scrapers-ca/) instead.**

## Getting Started

```
bundle
bundle exec rackup
```

### API

The only API endpoint is `/:id/:gid/:boundary_set`. For a Google Sheets URL of:

    https://docs.google.com/a/opennorth.ca/spreadsheets/d/7mOZ3yDOsmKJfg3s15S6GFEy6YAtFy461blJEemE81ML/edit#gid=059742683

* `:id` is the key `7mOZ3yDOsmKJfg3s15S6GFEy6YAtFy461blJEemE81ML`
* `:gid` is the parameter `059742683`
* `:boundary_set` is the slug of a boundary set in [Represent](http://represent.opennorth.ca/boundary-sets/?limit=0)

Copyright (c) 2015 Open North Inc., released under the MIT license
