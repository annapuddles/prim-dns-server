/* prim-dns file server v1.2.0
 *
 * This script is a request handler script which will serve specially-named
 * notecards in the prim's inventory as "files".
 */

/* The name used for the index notecard in each "directory". Note: XHTML is preferred because HTML can only be used by the internal SL browser, and only works for the owner of the linkset. */
string index_notecard = "index.xhtml";

/* The prefix for scripts which will act as caches for the file server. */
string cache_prefix = "prim-dns file server cache";

/* A list of cached notecards, the contents of which are stored in the cache scripts. */
list cached_notecards;

/* Paths registered by other request handler scripts that should not be treated as files. */
list registered_paths;

/* JSON-RPC functions */
string jsonrpc_request(string method, string params_type, list params, string id)
{
    if (id == "") id = (string) llGenerateKey();
    return llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "id", id, "method", method, "params", llList2Json(params_type, params)]);
}

string jsonrpc_notification(string method, string params_type, list params)
{
    return llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]);
}

string jsonrpc_link_request(integer link, string method, string params_type, list params, string id)
{
    if (id == "") id = (string) llGenerateKey();
    llMessageLinked(link, 0, jsonrpc_request(method, params_type, params, id), NULL_KEY);
    return id;
}

jsonrpc_link_notification(integer link, string method, string params_type, list params)
{
    llMessageLinked(link, 0, jsonrpc_notification(method, params_type, params), NULL_KEY);
}

/* Begin reading all the notecards into the cache */
store_notecards_in_cache()
{
    llOwnerSay("Updating notecard cache...");
    
    /* Clear the existing list of cached notecards */
    cached_notecards = [];
    
    /* The prim will have one or more cache scripts that start with the cache_prefix.
     * The contents of the cached notecards will be stored evenly among these scripts,
     * allowing the cache to be as big as desired by simply adding more cache scripts.
     */
     
    /* First, we get a list of all the cache scripts in the prim. */
    list cache_scripts;
    integer scripts = llGetInventoryNumber(INVENTORY_SCRIPT);
    integer i;
    
    for (i = 0; i <= scripts; ++i)
    {
        string name = llGetInventoryName(INVENTORY_SCRIPT, i);
        
        if (llGetSubString(name, 0, llStringLength(cache_prefix) - 1) == cache_prefix)
        {
            cache_scripts += name;
        }
    }
    
    integer total_cache_scripts = llGetListLength(cache_scripts);
    
    /* If there are no cache scripts, abort. */ 
    if (total_cache_scripts == 0)
    {
        return;
    }
    
    /* Next, get a list of all the notecards we need to cache. */
    integer notecards = llGetInventoryNumber(INVENTORY_NOTECARD);
    
    for (i = 0; i < notecards; ++i)
    {
        string name = llGetInventoryName(INVENTORY_NOTECARD, i);
        
        /* Only cache notecards starting with / */
        if (llGetSubString(name, 0, 0) == "/")
        {
            cached_notecards += llGetInventoryName(INVENTORY_NOTECARD, i);
        }
    }
    
    integer total_cached_notecards = llGetListLength(cached_notecards);
    
    /* Calculate how many notecards will be cached per script. */
    integer notecards_per_script = llCeil(total_cached_notecards / total_cache_scripts);
    
    /* Assign cache scripts to ranges of notecards based on the above. */
    for (i = 0; i < total_cache_scripts; ++i)
    {
        integer min = notecards_per_script * i;
        integer max = notecards_per_script * (i + 1) - 1;
        
        jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:cache:read", JSON_OBJECT, ["script", llList2String(cache_scripts, i), "start", min, "end", max]);        
    }
}

/* Perform a redirect using XHTML + Javascript, since we can't set the Location header of a response */
redirect(integer sender, key request_id, string location)
{
    jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_XHTML]);
    jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><script>window.location = '" + location + "';</script></head><body/></html>"]);
}

/* Determine the MIME type from the notecard's extension.
 * SL only supports certain predefined MIME types.
 */
integer get_content_type(string extension)
{
    if (extension == ".html")
    {
        return CONTENT_TYPE_HTML;
    }
    else if (extension == ".xml")
    {
        return CONTENT_TYPE_XML;
    }
    else if (extension == ".xhtml")
    {
        return CONTENT_TYPE_XHTML;
    }
    else if (extension == ".json")
    {
        return CONTENT_TYPE_JSON;
    }
    else
    {
        return CONTENT_TYPE_TEXT;
    }
}

default
{
    state_entry()
    {
        store_notecards_in_cache();
    }
    
    changed(integer change)
    {
        /* Re-cache notecards if inventory changes. */
        if (change & CHANGED_INVENTORY)
        {
            store_notecards_in_cache();
        }
    }
     
    link_message(integer sender, integer num, string str, key id)
    {
        string jsonrpc_method = llJsonGetValue(str, ["method"]);
        
        if (jsonrpc_method == "prim-dns:request")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            string method = llJsonGetValue(str, ["params", "method"]);
            string headers = llJsonGetValue(str, ["params", "headers"]);
            string body = llJsonGetValue(str, ["params", "body"]);
            
            /* Read the trailing path from the headers */
            string path = llJsonGetValue(headers, ["x-path-info"]);
                        
            /* If no path was given then redirect to the root path (/) */
            if (path == "" || path == JSON_INVALID)
            {
                redirect(sender, request_id, llJsonGetValue(headers, ["x-script-url"]) + "/");
                return;
            }
            
            /* Decode the path into plain text. */
            string name = llUnescapeURL(path);
            
            /* Ignore paths registered by other request handler scripts. */
            if (llListFindList(registered_paths, [name]) != -1)
            {
                return;
            }
            
            /* If the path ends in a /, treat it as a "directory". */
            if (llGetSubString(name, -1, -1) == "/")
            {
                name += index_notecard;
            }
            
            /* Get the extension of the name, or empty string if there is not . */
            string extension;
            integer dot_index = llSubStringIndex(name, ".");
            
            /* If there is an extension, store it. */
            if (dot_index > -1)
            {
                extension = llGetSubString(name, dot_index, -1);
            }
            /* If there is no extension, and no notecard with the name exists, treat this as a "directory". */
            else
            {
                if (llListFindList(cached_notecards, [name]) == -1)
                {
                    redirect(sender, request_id, llJsonGetValue(headers, ["x-script-url"]) + name + "/");
                    return;
                }
            }
            
            /* Find the notecard name in the list of cached notecards */
            integer index = llListFindList(cached_notecards, [name]);
            
            /* If there was no cached notecard with the specified name, return a 404 error */
            if (index == -1)
            {
                jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 404, "body", "Not found: " + name]);
            }
            /* If a notecard matching the name was found, message the cache scripts to get its content */
            else
            {
                /* Set the appropriate MIME type based on the notecard extension */
                jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", get_content_type(extension)]);
                
                /* Send a message to the cache scripts to find the cached notecard content */
                jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:cache:send", JSON_OBJECT, ["request-id", request_id, "name", name]);
            }
        }
        /* Forward cache responses to the prim-dns script. */
        else if (jsonrpc_method == "prim-dns:file-server:cache:response")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            string body = llJsonGetValue(str, ["params", "body"]);
            
            jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", body]);
        }
        /* Allow other scripts to register paths which will be ignored by the file server. */
        else if (jsonrpc_method == "prim-dns:file-server:register-path")
        {
            string path = llJsonGetValue(str, ["params", "path"]);
            
            if (llListFindList(registered_paths, [path]) == -1)
            {
                registered_paths += path;
            }
        }
    }
}
