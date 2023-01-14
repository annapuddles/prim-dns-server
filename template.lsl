string jsonrpc_notification(string method, string params_type, list params)
{
    return llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]);
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
            
            llMessageLinked(sender, 0, jsonrpc_notification("prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_HTML]), NULL_KEY);
            llMessageLinked(sender, 0, jsonrpc_notification("prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", "<b>Hello, world!</b>"]), NULL_KEY);
        }
    }
}
