/* This script controls the monitor on the example server mesh. */

/* Link number of the monitor. */
integer media_link = LINK_THIS;

/* Face to display media on. */
integer media_face = 1;

default
{
    link_message(integer sender, integer num, string str, key id)
    {
        string jsonrpc_method = llJsonGetValue(str, ["method"]);

        /* When a new URL is obtained, display that URL on the media. */
        if (jsonrpc_method == "prim-dns:url-request-granted")
        {
            string url = llJsonGetValue(str, ["params", "url"]) + "/";
            
            llSetLinkPrimitiveParamsFast(media_link, [PRIM_FULLBRIGHT, media_face, TRUE]);
            
            llSetLinkMedia(media_link, media_face, [
                PRIM_MEDIA_AUTO_PLAY, TRUE,
                PRIM_MEDIA_AUTO_SCALE, FALSE,
                PRIM_MEDIA_WIDTH_PIXELS, 512,
                PRIM_MEDIA_HEIGHT_PIXELS, 256,
                PRIM_MEDIA_CURRENT_URL, url,
                PRIM_MEDIA_PERMS_INTERACT, PRIM_MEDIA_PERM_ANYONE,
                PRIM_MEDIA_PERMS_CONTROL, PRIM_MEDIA_PERM_NONE
            ]);
        }
        /* When the server is shut down, remove the media. */
        else if (jsonrpc_method == "prim-dns:shutting-down")
        {
            llSetLinkPrimitiveParamsFast(media_link, [PRIM_FULLBRIGHT, media_face, FALSE]);
            llClearLinkMedia(media_link, media_face);
        }
    }
}
