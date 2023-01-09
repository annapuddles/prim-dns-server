# prim-dns:request (request-id, method, body)

The prim-dns script received an HTTP request.

## Parameters
- `request-id` The key of the request.
- `method` The HTTP method of the request.
- `body` The body of the request.

# prim-dns:set-content-type (request-id, content-type)

Set the content type of the response.

## Parameters
- `request-id` The key of the request to set the response content type for.
- `content-type` One of the supported content type constants.

## Example

```lsl
string params = llList2Json(JSON_OBJECT, [
    "request-id", request_id,
    "content-type", CONTENT_TYPE_HTML
]);

string message = llList2Json(JSON_OBJECT, [
    "method", "prim-dns:set-content-type",
    "params", params
]);

llMessageLinked(LINK_THIS, 0, message, NULL_KEY);
```

# prim-dns:response (request-id, status, body)

Send the response.

## Parameters
- `request-id` The key of the request to respond to.
- `status` The HTTP status code of the response.
- `body` The body of the response.

## Example

```lsl
string params = llList2Json(JSON_OBJECT, [
    "request-id", request_id,
    "status", 200,
    "body", "Hello, world!"
]);

string message = llList2son(JSON_OBJECT, [
    "method", "prim-dns:response",
    "params", params
]);

llMessageLinked(LINK_THIS, 0, message, NULL_KEY);
```

# prim-dns:reboot ()

Reboot the prim-dns server.

## Example

```lsl
string message = llList2Json(JSON_OBJECT, [
    "method", "prim-dns:reboot"
]);

llMessageLinked(LINK_THIS, 0, message, NULL_KEY);
```

# prim-dns:shutdown ()

Shut down the prim-dns server.

## Example

```lsl
string message = llList2Json(JSON_OBJECT, [
    "method", "prim-dns:shutdown"
]);

llMessageLinked(LINK_THIS, 0, message, NULL_KEY);
```

# prim-dns:startup ()

Sent when the prim-dns server finishes reading the configuration and is waiting to continue starting up. If auto_start = 1, then the server will immediately continue, otherwise it will wait for the prim-dns:start messsage.

# prim-dns:start ()

Tell the prim-dns server to complete its startup.

```lsl
string message = llList2Json(JSON_OBJECT, [
    "method", "prim-dns:start"
]);

llMessageLinked(LINK_THIS, 0, message, NULL_KEY);
```
