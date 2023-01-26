# prim-dns file server

The prim-dns file server is a request handler script which will serve specially-named notecards in the prim's inventory as "files". Notecards must be named after the path of the file, including slashes. The example [index.xhtml](index.xhtml) notecard would actually be named `/index.xhtml` in the prim's inventory.

The contents of notecards are cached for faster retrieval than reading the notecard each time it is requested. The cache is stored in one or more [prim-dns file server cache](prim-dns%20file%20server%20cache.lsl) scripts. You can add as many of these scripts as you like in order to increase the maximum size of the cache, as long as the name of each script begins with `prim-dns file server cache`.

The script will determine the MIME type from the "extension" in the name of the notecard. For example, `/index.xhtml` will use `CONTENT_TYPE_XHTML` (`application/xhtml+xml`), while `/data.json` will use `CONTENT_TYPE_JSON` (`application/json`). [The available MIME types are limited](https://wiki.secondlife.com/wiki/LlSetContentType) and cannot be customized. Anything without a known extension will be treated as `CONTENT_TYPE_TEXT` (`text/plain`).

Paths that end in `/` are treated as "directories". The script will attempt to serve a corresponding `index.xhtml` notecard for the "directory". For example, if the path is `/example/`, the script will attempt to server the contents of a notecard named `/example/index.xhtml`.

Paths with no file extension that do not match a notecard with the appropriate name are also treated as "directories", but will redirect to add the trailing `/`. For example, if the path is `/example`, and there is no notecard named `/example` in the inventory, then the page will redirect to `/example/`.

When using the file server, all paths that do not match a notecard will return a 404 error. In order to combine the file server with other request handler scripts that dynamically handle some paths, those scripts must register the paths they will handle with the file server. This is done by sending the `prim-dns:file-server:register-path` notification to the file server script via a JSON-RPC link message:
```lsl
jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:register-path", JSON_OBJECT, ["path", "/data.json"]);
```

## Known issues

- Use of HTML files is very limited as described [here](https://wiki.secondlife.com/wiki/LlSetContentType#Caveats).
  - You can use XHTML instead for the same thing with none of those limitations.
- The MIME types you can use are limited to those listed [here](https://wiki.secondlife.com/wiki/LlSetContentType).
  - CSS notecards can't be used because browsers will reject loading CSS that does not have the MIME type `text/css`.
    - You can embed CSS directly in XHTML pages instead.
    - Browsers seem to accept Javascript without `text/javascript`, so Javascript notecards are fine.
- A single notecard cannot be greater than the memory available to a single cache script.
  - This could be improved in the future by allowing notecards to be split between two or more cache scripts.
