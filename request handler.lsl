/* This is an example request handler script for prim-dns.
 *
 * Requests are forwarded from the main prim-dns script to request handlers via
 * JSON-RPC link messages. The request handler script processes the request, and
 * sends a response back to the main prim-dns script via another JSON-RPC link
 * message.
 *
 * You can add as many request handlers as you like, that can handle different
 * types of requests. For example, different handlers may choose to respond only
 * to requests to specific paths.
 */
 
/* The following functions are taken from
 * https://github.com/annapuddles/jsonrpc-sl and are used to create and send
 * JSON-RPC notifications via link message.
 */
string jsonrpc_notification(string method, string params_type, list params)
{
    return llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]);
}

jsonrpc_link_notification(integer link, string method, string params_type, list params)
{
    llMessageLinked(link, 0, jsonrpc_notification(method, params_type, params), NULL_KEY);
}

default
{
    link_message(integer sender, integer num, string str, key id)
    {
        /* Retrieve the JSON-RPC method name from the notification. */
        string jsonrpc_method = llJsonGetValue(str, ["method"]);
        
        /* Requests are forwarded using the prim-dns:request notification. */
        if (jsonrpc_method == "prim-dns:request")
        {
            /* The request key from http_request. */
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            
            /* The HTTP method (GET, POST) of the request. */
            string method = llJsonGetValue(str, ["params", "method"]);
            
            /* The request headers in a JSON object. */
            string headers = llJsonGetValue(str, ["params", "headers"]);
            
            /* The request body. */
            string body = llJsonGetValue(str, ["params", "body"]);
            
            /* Set the content type of the response. */
            jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_XHTML]);

            /* Send the response body. */
            jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body style=\"background-color: black; color: green; font-family: monospace;\"><b>Hello, world!</b></body></html>"]);
        }
    }
}
