json_link_message(integer link, string method, list params)
{    
    llMessageLinked(link, 0, llList2Json(JSON_OBJECT, ["method", method, "params", llList2Json(JSON_OBJECT, params)]), NULL_KEY);
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
        
        json_link_message(sender, "prim-dns:set-content-type", ["request-id", request_id, "content-type", CONTENT_TYPE_HTML]);
        json_link_message(sender, "prim-dns:response", ["request-id", request_id, "status", 200, "body", "<b>Hello, world!</b>"]);
    }
}
