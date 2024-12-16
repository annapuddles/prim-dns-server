/* prim-dns v2.7.1
 *
 * The prim-dns server script is a modular SecondLife script that will request
 * a temporary URL and register that URL with a prim-dns web service instance
 * to automatically create a permanent alias, which client scripts can use to
 * find the current temporary URL of the server at any given time. This allows
 * you to quickly add robust HTTP server functionality to any prim, and the
 * modular design means the core script can be updated without needing to edit
 * your own code, and different functions of a server can be split across
 * multiple scripts for easier management.
 */

/* CONFIGURATION */

/* The version of prim-dns. */
string version = "2.7.1";

/* The name of the configuration notecard. */
string config_notecard = "prim-dns config";

/* The URL of the prim-dns webservice. */
string prim_dns_api = "https://annapuddles.com/prim-dns/alias";

/* The alias registered on the prim-dns service. If blank, the object key will be used. */
string prim_dns_alias;

/* The authorization string used to update the URL alias */
string prim_dns_auth;

/* How often in seconds the server statistics text should be updated. 0 will disable status text completely. */
float status_update_interval = 1;

/* Whether to use a secure (https) or insecure (http) URL. */
integer use_secure_url = FALSE;

/* Whether to automatically start the server, or wait for a signal from a script. */
integer auto_start = TRUE;

/* Whether any hover text will be shown or not. */
integer text_enabled = TRUE;

/* The colour of the hover text displayed over the prim. */
vector text_color = <1, 1, 1>;

/* The opacity of the hover text displayed over the prim. */
float text_alpha = 1;

/* Whether the menu system is enabled or not. */
integer enable_menus = TRUE;

/* Whether messages will be shown in chat. */
integer enable_chat_output = TRUE;

/* Whether to automatically reboot on inventory change. */
integer auto_reboot = FALSE;

/* Text labels for dialogs. */
string power_on_label = "⏻ power on";
string cancel_label = "❌ cancel";
string reboot_label = "🔄 reboot";
string shutdown_label = "🛑 shutdown";
string info_label = "🖥️ info";
string ok_label = "✅ OK";

/* END OF CONFIGURATION */

/* The actual temporary prim URL assigned by llRequestURL */
string temporary_url;

/* The current line of the config notecard that is being read. */
integer config_notecard_line;

/* ID of the config notecard dataserver query. */
key config_notecard_query_id;

/* ID of the prim-dns HTTP request. */
key prim_dns_request_id;

/* Channel which dialogs will use. */
integer dialog_channel;

/* Listener for dialogs. */
integer dialog_listener;

/* Log messages to chat if enabled. */
log(string text)
{
    if (enable_chat_output)
    {
        llOwnerSay(text);
    }
}

/* Convert a time in seconds to a human-readable string. */
string time_to_string(float time)
{
    integer t = (integer) time;
    
    integer weeks = t / 604800;
    integer days = (t / 86400) % 7;
    integer hours = (t / 3600) % 24;
    integer minutes = (t / 60) % 60;
    integer seconds = t % 60;
    
    list parts;
    
    if (weeks > 0)
    {
        parts += (string) weeks + " weeks";
    }
    if (days > 0)
    {
        parts += (string) days + " days";
    }
    if (hours > 0)
    {
        parts += (string) hours + " hours";
    }
    if (minutes > 0)
    {
        parts += (string) minutes + " minutes";
    }
    
    parts += (string) seconds + " seconds";
    
    return llDumpList2String(parts, ", ");
}

/* Change settings based on config file name. */
change_setting(string setting, string value)
{
    if (setting == "api")
    {
        prim_dns_api = value;
    }
    else if (setting == "alias")
    {
        prim_dns_alias = value;
    }
    else if (setting == "auth")
    {
        prim_dns_auth = value;
    }
    else if (setting == "secure_url")
    {
        use_secure_url = (integer) value;
    }
    else if (setting == "status_update_interval")
    {
        status_update_interval = (float) value;
    }
    else if (setting == "auto_start")
    {
        auto_start = (integer) value;
    }
    else if (setting == "text_enabled")
    {
        if (text_enabled != (integer) value)
        {
            clear_text();
        }
        
        text_enabled = (integer) value;
        
        if (!text_enabled)
        {
            status_update_interval = 0;
        }
    }
    else if (setting == "text_color")
    {
        text_color = (vector) value;
    }
    else if (setting == "text_alpha")
    {
        text_alpha = (float) value;
    }
    else if (setting == "enable_menus")
    {
        enable_menus = (integer) value;
    }
    else if (setting == "enable_chat_output")
    {
        enable_chat_output = (integer) value;
    }
    else if (setting == "auto_reboot")
    {
        auto_reboot = (integer) value;
    }
}

/* JSON-RPC functions */
jsonrpc_link_notification(integer link, string method, string params_type, list params)
{
    llMessageLinked(link, 0, llList2Json(JSON_OBJECT, ["jsonrpc", "2.0", "method", method, "params", llList2Json(params_type, params)]), NULL_KEY);
}

/* The names of all the possible headers in a request. */
list HEADER_NAMES = [
    "x-script-url",
    "x-path-info",
    "x-query-string",
    "x-remote-ip",
    "user-agent",
    "connection",
    "cache-control",
    "x-forwarded-for",
    "via",
    "content-length",
    "pragma",
    "x-secondlife-shard",
    "x-secondlife-region",
    "x-secondlife-owner-name",
    "x-secondlife-owner-key",
    "x-secondlife-object-name",
    "x-secondlife-object-key",
    "x-secondlife-local-velocity",
    "x-secondlife-local-rotation",
    "x-secondlife-local-position",
    "content-type",
    "accept-charset",
    "accept",
    "accept-encoding",
    "host"
];

/* Get the request headers as a JSON object. */
string get_request_headers(key request_id)
{
    list headers;
    integer length = llGetListLength(HEADER_NAMES);
    integer i;
    
    for (i = 0; i < length; ++i)
    {
        string name = llList2String(HEADER_NAMES, i);
        string value = llGetHTTPHeader(request_id, name);
        
        if (value != "")
        {
            headers += [name, value];
        }
    }
    
    return llList2Json(JSON_OBJECT, headers);
}

set_text(string text)
{
    if (text_enabled)
    {
        llSetText(text, text_color, text_alpha);
    }
}

clear_text()
{
    if (text_enabled)
    {
        llSetText("", ZERO_VECTOR, 0);
    }
}

string get_stats()
{
    string stats;
    
    stats += "⏱️ Uptime: " + time_to_string(llGetTime()) + "\n";
    
    integer data_avail = llLinksetDataAvailable();
    integer data_percent = (integer) (data_avail / 131072.0 * 100);
    stats += "💽 Storage Remaining: " + (string) data_percent + "% (" + (string) ((integer) (data_avail / 1024)) + " KiB / 128 KiB)";
    
    return stats;
}

process_configuration_notecard_line(string data)
{
    /* Ignore lines that start with #, treating them as comments */
    if (llGetSubString(data, 0, 1) != "#")
    {
        list parts = llParseStringKeepNulls(data, [" = "], []);
        
        if (llGetListLength(parts) == 2)
        {
            string setting = llList2String(parts, 0);
            string value = llList2String(parts, 1);
            
            change_setting(setting, value);
        }
    }
}

default
{
    state_entry()
    {
        /* Get a unique channel number based on the object's key. */
        dialog_channel = 0x80000000 | (integer)("0x"+(string)llGetKey());
        
        llOwnerSay("Free memory: " + (string) llGetFreeMemory());
        
        state off;
    }
}

/* In the off state, the server waits to be started by the owner. */
state off
{
    state_entry()
    {
        set_text("⏻ Touch to start");
    }
    
    touch_end(integer detected)
    {
        key toucher = llDetectedKey(0);
        
        if (toucher != llGetOwner())
        {
            return;
        }
        
        llListenRemove(dialog_listener);
        dialog_listener = llListen(dialog_channel, "", toucher, "");
        llDialog(toucher, "prim-dns v" + version, [power_on_label, cancel_label], dialog_channel);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(dialog_listener);
        
        if (message == power_on_label)
        {
            state read_configuration;
        }
    }
}

/* In the read_configuration state, the server settings are initialized by reading the config notecard. */
state read_configuration
{
    state_entry()
    {
        set_text("📄 Reading configuration...");
        jsonrpc_link_notification(LINK_SET, "prim-dns:read-config-start", JSON_OBJECT, []);
        
        /* If the config notecard doesn't exist, abort. */
        if (llGetInventoryType(config_notecard) != INVENTORY_NOTECARD)
        {
            state startup;
        }
        
        /* Reset these saved settings to their default values. */
        prim_dns_alias = "";
        prim_dns_auth = "";
        
        /* Read the first line of the notecard. */
        config_notecard_query_id = llGetNotecardLine(config_notecard, config_notecard_line = 0);
    }
    
    /* Read each line of the config notecard. */
    dataserver(key query_id, string data)
    {
        /* Ignore dataserver events from other scripts. */
        if (query_id != config_notecard_query_id)
        {
            return;
        }

        /* Attempt to read the notecard synchronously, if it is in the region cache. */
        while (data != EOF && data != NAK)
        {
            data = llGetNotecardLineSync(config_notecard, ++config_notecard_line);
            process_configuration_notecard_line(data);
        }

        /* If the notecard is not in the region cache, read it asynchronously. */
        if (data == NAK)
        {
            config_notecard_query_id = llGetNotecardLine(config_notecard, ++config_notecard_line);
        }
        
        /* If there are no more lines to read, stop. */
        if (data == EOF)
        {
            state startup;
        }
    }
    
    state_exit()
    {
        clear_text();
        jsonrpc_link_notification(LINK_SET, "prim-dns:read-config-end", JSON_OBJECT, []);
    }
}

/* In the startup state, the script will wait to receive the "start" message from another script. */
state startup
{
    state_entry()
    {
        set_text("🕙 Waiting for startup...");
        
        jsonrpc_link_notification(LINK_SET, "prim-dns:startup", JSON_OBJECT, []);
        
        if (auto_start)
        {
            state request_url;
        }
    }
    
    changed(integer change)
    {
        if (auto_reboot && (change & CHANGED_INVENTORY))
        {
            state read_configuration;
        }
    }
    
    link_message(integer sender, integer num, string str, key id)
    {
        string method = llJsonGetValue(str, ["method"]);
        
        if (method == "prim-dns:start")
        {
            state request_url;
        }
    }
    
    /* Present an options menu on touch. */
    touch_start(integer detected)
    {
        if (!enable_menus)
        {
            return;
        }
        
        key toucher = llDetectedKey(0);
    
        if (toucher != llGetOwner())
        {
            return;
        }
        
        llListenRemove(dialog_listener);
        dialog_listener = llListen(dialog_channel, "", toucher, "");
        llDialog(toucher, "prim-dns v" + version, [reboot_label, shutdown_label, cancel_label], dialog_channel);
    }
    
    /* Handle the response from the options menu. */
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(dialog_listener);
        
        if (message == reboot_label)
        {
            state reboot;
        }
        else if (message == shutdown_label)
        {
            state shutdown;
        }
    }
    
    state_exit()
    {
        clear_text();
    }
}

/* In the request_url state, the script requests a URL, and registers it with the prim-dns service. */
state request_url
{
    state_entry()
    {
        set_text("🛜 Requesting URL...");
        
        /* Release any current temporary URL in use. */
        llReleaseURL(temporary_url);
        
        /* Request a URL, either secure or insecure based on the use_secure_url setting. */
        if (use_secure_url)
        {
            llRequestSecureURL();
        }
        else
        {
            llRequestURL();
        }
    }
    
    /* Handle HTTP requests made to this prim. */
    http_request(key request_id, string method, string body)
    {
        /* If the SecondLife server granted the script a URL, it will send an HTTP request to the prim with the URL */
        if (method == URL_REQUEST_GRANTED)
        {
            temporary_url = body;
            log("URL request granted: " + temporary_url);
            jsonrpc_link_notification(LINK_SET, "prim-dns:url-request-granted", JSON_OBJECT, ["url", temporary_url]);
            
            /* If prim_dns_api is unset, don't use any prim-dns web service. */
            if (prim_dns_api == "")
            {
                state main;
            }
            
            /* Use the obtained temporary URL and auth string to update the permanent URL alias */
            
            /* Create the headers for the request. */
            list headers = [
                HTTP_METHOD, "POST",
                HTTP_MIMETYPE, "application/json",
                HTTP_CUSTOM_HEADER, "Authorization", prim_dns_auth
            ];
            
            string name;
            
            /* If no name is given for the alias, use the object's key. */
            if (prim_dns_alias == "")
            {
                name = llGetKey();
            }
            else
            {
                name = prim_dns_alias;
            }
            
            /* Create the body data for the request. */
            list body = [
                "name", name,
                "url", temporary_url
            ];
            
            /* Make the request to the prim-dns webservice. */
            prim_dns_request_id = llHTTPRequest(prim_dns_api, headers, llList2Json(JSON_OBJECT, body));
        }
        /* If for some reason the SecondLife server denied the request, display the reason */
        else if (method == URL_REQUEST_DENIED)
        {
            log("URL request denied: " + body);
            
            llSetTimerEvent(30);
        }
    }
    
    /* Handle the response from the prim-dns webservice */
    http_response(key request_id, integer status, list metadata, string body)
    {
        /* Ignore HTTP responses triggered by other scripts. */
        if (request_id != prim_dns_request_id)
        {
            return;
        }
        
        /* If we received a successful response from the webservice... */
        if (status == 200)
        {
            string auth = llJsonGetValue(body, ["auth"]);
            string endpoint = llJsonGetValue(body, ["endpoint"]);
            
            /* If not auth string is returned in the response, then we must be updating an existing alias. */
            if (auth == JSON_INVALID)
            {
                log("Server URL updated successfully for " + endpoint);
            }
            /* If an auth string is returned, this must be a new alias. */
            else
            {
                log("Server URL registered successfully at " + endpoint);
                log("****************************************\nCOPY THIS LINE INTO THE " + config_notecard + " NOTECARD:\n\nauth = " + llJsonGetValue(body, ["auth"]) + "\n\n****************************************");
            }

            jsonrpc_link_notification(LINK_SET, "prim-dns:alias-registered", JSON_OBJECT, ["alias", endpoint]);
            
            state main;
        }
        /* If the webservice responded with an error, display it */
        else
        {
            llOwnerSay("Registration failed: [" + (string) status + "] " + llJsonGetValue(body, ["error"]));
            
            llSetTimerEvent(30);
        }
    }
    
    /* Reboot automatically if no URL can be obtained. */
    timer()
    {
        state read_configuration;
    }
    
    /* Present an options menu on touch. */
    touch_start(integer detected)
    {
        if (!enable_menus)
        {
            return;
        }
        
        key toucher = llDetectedKey(0);
        
        if (toucher != llGetOwner())
        {
            return;
        }
        
        llListenRemove(dialog_listener);
        dialog_listener = llListen(dialog_channel, "", toucher, "");
        llDialog(toucher, "prim-dns v" + version, [reboot_label, shutdown_label, cancel_label], dialog_channel);
    }
    
    /* Handle the response from the options menu. */
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(dialog_listener);
        
        if (message == reboot_label)
        {
            state reboot;
        }
        else if (message == shutdown_label)
        {
            state shutdown;
        }
    }
    
    changed(integer change)
    {
        if (auto_reboot && (change & CHANGED_INVENTORY))
        {
            state read_configuration;
        }
    }
    
    state_exit()
    {
        llSetTimerEvent(0);
        clear_text();
    }
}

/* In the main state, handle normal requests. */
state main
{
    state_entry()
    {
        llResetTime();
        set_text("✅ Ready!");
        jsonrpc_link_notification(LINK_SET, "prim-dns:startup-complete", JSON_OBJECT, []);
        if (status_update_interval > 0)
        {
            llSetTimerEvent(status_update_interval);
        }
        else
        {
            llSetTimerEvent(1);
        }
    }
    
    /* Update the server statistics text. */
    timer()
    {
        if (status_update_interval == 0)
        {
            clear_text();
            return;
        }
                
        set_text(get_stats());
    }
    
    state_exit()
    {
        clear_text();
        llSetTimerEvent(0);
    }
    
    /* If the object is de-rezzed and then rezzed again, we must request a new URL */
    on_rez(integer param)
    {
        /* When rezzed, the object has a new key, so if the key is used as the alias, a new auth is required. */
        if (prim_dns_alias == "")
        {
            prim_dns_auth = "";
        }
        
        state request_url;
    }
    
    changed(integer change)
    {
        /* If the inventory changes (for example, after updating the config notecard), re-initialize. */
        if (auto_reboot && (change & CHANGED_INVENTORY))
        {
            state read_configuration;
        }
        
        /* If the prim changes regions or the region the prim is in restarts, we must request a new URL */
        if (change & (CHANGED_REGION | CHANGED_REGION_START))
        {
            state request_url;
        }
    }

    /* Pass the request data to linked prims in a JSON-RPC message. */
    http_request(key request_id, string method, string body)
    {        
        jsonrpc_link_notification(LINK_SET, "prim-dns:request", JSON_OBJECT, ["request-id", request_id, "method", method, "headers", get_request_headers(request_id), "body", body]);
    }
    
    /* Process JSON-RPC messages from linked prims. */
    link_message(integer sender, integer num, string str, key id)
    {
        string method = llJsonGetValue(str, ["method"]);
        
        if (method == "prim-dns:set-content-type")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            integer content_type = (integer) llJsonGetValue(str, ["params", "content-type"]);
            
            llSetContentType(request_id, content_type);
        }
        else if (method == "prim-dns:response")
        {
            key request_id = (key) llJsonGetValue(str, ["params", "request-id"]);
            integer status = (integer) llJsonGetValue(str, ["params", "status"]);
            string body = llJsonGetValue(str, ["params", "body"]);
            
            llHTTPResponse(request_id, status, body);
        }
        else if (method == "prim-dns:reboot")
        {
            state reboot;
        }
        else if (method == "prim-dns:shutdown")
        {
            state shutdown;
        }
    }
    
    /* Present an options menu on touch. */
    touch_start(integer detected)
    {
        if (!enable_menus)
        {
            return;
        }
        
        key toucher = llDetectedKey(0);
        
        if (toucher != llGetOwner())
        {
            return;
        }
        
        llListenRemove(dialog_listener);
        dialog_listener = llListen(dialog_channel, "", toucher, "");
        llDialog(toucher, "prim-dns v" + version, [" ", "cancel", " ", info_label, reboot_label, shutdown_label], dialog_channel);
    }
    
    /* Handle the response from the options menu. */
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(dialog_listener);
        
        if (message == reboot_label)
        {
            state reboot;
        }
        else if (message == shutdown_label)
        {
            state shutdown;
        }
        else if (message == info_label)
        {
            string text = "prim-dns v" + version;
            text += "\n\n" + get_stats();
            text += "\n\n🌎 URL: " + temporary_url;
            
            if (prim_dns_api != "")
            {
                string alias;
                if (prim_dns_alias == "")
                {
                    alias = llGetKey();
                }
                else
                {
                    alias = prim_dns_alias;
                }
                text += "\n\n🪪 Alias: " + prim_dns_api + "/" + alias;
            }
            
            llDialog(id, text, [ok_label], dialog_channel);
        }
    }
}
 
state reboot
{
    state_entry()
    {
        set_text("🔄 Rebooting...");
        jsonrpc_link_notification(LINK_SET, "prim-dns:shutting-down", JSON_OBJECT, []);
        state read_configuration;
    }
     
    state_exit()
    {
        clear_text();
    }
}

state shutdown
{
    state_entry()
    {
        set_text("🛑 Shutting down...");
        jsonrpc_link_notification(LINK_SET, "prim-dns:shutting-down", JSON_OBJECT, []);
        state off;
    }

    state_exit()
    {
        clear_text();
    }
}
