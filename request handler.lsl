/* JSON-RPC functions */
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
        string jsonrpc_method = llJsonGetValue(str, ["method"]);
        
        if (jsonrpc_method == "prim-dns:request")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            string method = llJsonGetValue(str, ["params", "method"]);
            string headers = llJsonGetValue(str, ["params", "headers"]);
            string body = llJsonGetValue(str, ["params", "body"]);
            
            jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_XHTML]);
            jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body style=\"background-color: black; color: green; font-family: monospace;\"><b>Hello, world!</b></body></html>"]);
        }
    }
}
