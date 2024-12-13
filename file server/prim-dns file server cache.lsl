/* prim-dns file server cache script v1.1.1
 *
 * This script stores the contents of notecards in the inventory in memory, for
 * faster access when responding to an HTTP request.
 *
 * You may add as many cache scripts to your server as you like (within the
 * overall SL script limit) to increase the maximum size of the cache.
 */

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

/* The query ID for dataserver event. */
key notecard_query;

/* A strided list of notecard names and their contents. */
list cache;

/* Read the next notecard into the cache. */
read_next_notecard()
{
    notecard_content = "";
    
    if (notecard_index <= max_notecard_index)
    {
        notecard_name = llGetInventoryName(INVENTORY_NOTECARD, notecard_index++);
        notecard_query = llGetNotecardLine(notecard_name, notecard_line = 0);
    }
    else
    {
        notecard_name = "";
        llOwnerSay(llGetScriptName() + ": " + (string) (llGetUsedMemory() / 1024) + " KiB");
    }
}

default
{
    link_message(integer sender, integer num, string str, key id)
    {
        string method = llJsonGetValue(str, ["method"]);
        
        /* Read designated notecards from the inventory into the cache. */
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
        /* Send a cached notecard's contents back to the main script if this script has it. */
        else if (method == "prim-dns:file-server:cache:send")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            string name = llJsonGetValue(str, ["params", "name"]);
            
            integer index = llListFindList(cache, [name]);
            
            if (index == -1)
            {
                return;
            }
            
            llMessageLinked(sender, 0, llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", "prim-dns:file-server:cache:response", "params", llList2Json(JSON_OBJECT, ["request-id", request_id, "body", llList2String(cache, index + 1)])]), NULL_KEY);
        }
    }
    
    dataserver(key id, string data)
    {
        if (id != notecard_query)
        {
            return;
        }
        
        while (data != EOF && data != NAK)
        {
            notecard_content += data + "\n";
            data = llGetNotecardLineSync(notecard_name, ++notecard_line);
        }
        
        if (data == EOF)
        {
            cache += [notecard_name, notecard_content];
            read_next_notecard();
        }
        
        if (data == NAK)
        {
            notecard_query = llGetNotecardLine(notecard_name, ++notecard_line);
        }
    }
}
