jsonrpc_link_notification(integer link, string method, string params_type, list params)
{
    llMessageLinked(link, 0, llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]), NULL_KEY);
}

default
{
    link_message(integer sender, integer num, string str, key id)
    {
        if (llJsonGetValue(str, ["method"]) != "prim-dns:request")
        {
            return;
        }
        
        key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
        string method = llJsonGetValue(str, ["params", "method"]);
        string body = llJsonGetValue(str, ["params", "body"]);
        
        jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_HTML]);
        jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", "<b>Hello, world!</b>"]);
    }
}
