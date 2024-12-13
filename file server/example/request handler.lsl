/* This script handles requests to special paths which return dynamic responses using LSL. */

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
        
        /* Register the paths this script will handle instead of the file server.
         *
         * This really only needs to be done once, after the file server script
         * starts, but just in case we'll register it each time the server starts
         * up.
         */
        if (jsonrpc_method == "prim-dns:startup")
        {
            jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:register-path", JSON_OBJECT, ["path", "/agents/agents.json"]);
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
            
            /* /agents/agents.json: Return a list of details about avatars in the region. */
            if (path == "/agents/agents.json")
            {
                list agents = llGetAgentList(AGENT_LIST_REGION, []);
                integer total_agents = llGetListLength(agents);
                list agentList;
                integer i;
                
                for (i = 0; i < total_agents; ++i)
                {
                    key agent = llList2Key(agents, i);
                    
                    list details = llGetObjectDetails(agent, [OBJECT_POS]);
                    
                    agentList += llList2Json(JSON_OBJECT, [
                        "key", agent,
                        "username", llGetUsername(agent),
                        "displayName", llGetDisplayName(agent),
                        "position", llList2Vector(details, 0)
                    ]);
                }

                string out = llList2Json(JSON_OBJECT, [
                    "region", llGetRegionName(),
                    "agentList", llList2Json(JSON_ARRAY, agentList)
                ]);
                
                jsonrpc_link_notification(sender, "prim-dns:set-content-type", JSON_OBJECT, ["request-id", request_id, "content-type", CONTENT_TYPE_JSON]);
                jsonrpc_link_notification(sender, "prim-dns:response", JSON_OBJECT, ["request-id", request_id, "status", 200, "body", out]);
            }
        }
    }
}
