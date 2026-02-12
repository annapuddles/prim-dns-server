/* prim-dns file server images plugin v1.0.0
 *
 * This plugin provides a way to use textures in your object's inventory as
 * images within web pages.
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
        string jsonrpc_method = llJsonGetValue(str, ["method"]);
        
        /* Register dynamic paths on startup. */
        if (jsonrpc_method == "prim-dns:startup")
        {
            /* /images.json */
            jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:register-path", JSON_OBJECT, ["path", "/images.json"]);
        }
        /* Handle requests forwarded from the main prim-dns script. */
        else if (jsonrpc_method == "prim-dns:request")
        {
            /* The ID of the HTTP request. */
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            
            /* The method of the HTTP request (GET, POST). */
            string method = llJsonGetValue(str, ["params", "method"]);
            
            /* The headers of the HTTP request, as a JSON object. */
            string headers = llJsonGetValue(str, ["params", "headers"]);
            
            /* The body of the HTTP request. */
            string body = llJsonGetValue(str, ["params", "body"]);
            
            /* Get the path from the headers and use it to determine the response. */
            string path = llJsonGetValue(headers, ["x-path-info"]);
            
            /* /images.json: Return a map of texture names and UUIDs. */
            if (path == "/images.json")
            {
                integer num_textures = llGetInventoryNumber(INVENTORY_TEXTURE);
                list images;
                for (--num_textures; num_textures >= 0; --num_textures)
                {
                    string name = llGetInventoryName(INVENTORY_TEXTURE, num_textures);
                    images = [name, llGetInventoryKey(name)];
                }
                
                jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_JSON]);
                jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", llList2Json(JSON_OBJECT, images)]);
            }
        }
    }
}
