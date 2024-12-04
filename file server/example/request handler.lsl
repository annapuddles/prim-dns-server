/* This script handles requests to special paths which return dynamic responses using LSL. */

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
    state_entry()
    {
        /* Register the paths this script will handle instead of the file server. */
        jsonrpc_link_notification(LINK_SET, "prim-dns:file-server:register-path", JSON_OBJECT, ["path", "/agents/agents.json"]);
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
            
            /* Get the path from the headers and use it to determine the response. */
            string path = llJsonGetValue(headers, ["x-path-info"]);
            
            if (path == "/agents/agents.json")
            {
                list agents = llGetAgentList(AGENT_LIST_REGION, []);
                integer total_agents = llGetListLength(agents);
                list agentList;
                integer i;
                
                for (i = 0; i < total_agents; ++i)
                {
                    key agent = llList2Key(agents, i);
                    
                    agentList += llList2Json(JSON_OBJECT, [
                        "key", agent,
                        "username", llGetUsername(agent),
                        "displayName", llGetDisplayName(agent)
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
