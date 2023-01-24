/* prim-dns file server cache script, version 1.0.0 */

/* The content of the current notecard being read. */
string notecard_content;

/* The current line of the current notecard being read. */
integer notecard_line;

/* The index of the current notecard being read. */
integer notecard_index;

/* The name of the current notecard being read. */
string notecard_name;

/* The index of the last notecard that this cache script should read. */
integer max_notecard_index;

key notecard_query;

/* A strided list of notecard names and their contents. */
list cache;

string jsonrpc_notification(string method, string params_type, list params)
{
    return llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]);
}

jsonrpc_link_notification(integer link, string method, string params_type, list params)
{
    llMessageLinked(link, 0, jsonrpc_notification(method, params_type, params), NULL_KEY);
}

/* Read the next notecard into the cache. */
read_next_notecard()
{
    notecard_content = "";
    
    if (notecard_index <= max_notecard_index)
    {
        notecard_name = llGetInventoryName(INVENTORY_NOTECARD, notecard_index++);
        notecard_line = 0;
        notecard_query = llGetNotecardLine(notecard_name, notecard_line++);
    }
    else
    {
        notecard_name = "";
        llOwnerSay(llGetScriptName() + ": " + (string) (llGetUsedMemory() / 1024) + " KiB");
    }
}

/* Send a cached notecard's contents back to the main script if this script has it. */
send_cached_notecard(integer sender, key request_id, string name)
{
    integer index = llListFindList(cache, [name]);
    
    if (index == -1)
    {
        return;
    }
        
    jsonrpc_link_notification(sender, "prim-dns:file-server:cache:response", JSON_OBJECT, ["request-id", request_id, "body", llList2String(cache, index + 1)]);
}

default
{
    link_message(integer sender, integer num, string str, key id)
    {
        string method = llJsonGetValue(str, ["method"]);
        
        if (method == "prim-dns:file-server:cache:read")
        {
            string script = llJsonGetValue(str, ["params", "script"]);
            
            if (script != llGetScriptName())
            {
                return;
            }
            
            cache = [];
                        
            notecard_index = (integer) llJsonGetValue(str, ["params", "start"]);
            max_notecard_index = (integer) llJsonGetValue(str, ["params", "end"]);
                                    
            read_next_notecard();
        }
        else if (method == "prim-dns:file-server:cache:send")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            string name = llJsonGetValue(str, ["params", "name"]);
                        
            send_cached_notecard(sender, request_id, name);
        }
    }
    
    dataserver(key id, string data)
    {
        if (id != notecard_query)
        {
            return;
        }
        
        if (data == EOF)
        {
            cache += [notecard_name, notecard_content];
            read_next_notecard();
        }
        else
        {
            notecard_content += data + "\n";
            notecard_query = llGetNotecardLine(notecard_name, notecard_line++);
        }
    }
}
