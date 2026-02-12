This is a plugin for the prim-dns file server that provides an easy method to use textures in your server object's inventory as images on your web pages.

To use this plugin, add the `prim-dns file server images plugin` script and the `/images.js` notecard to your server. Then, in any pages where you want to include images, include image.js via a script tag:
```xml
<script src="images.js"/>
```
Note that the URL may need to be adjusted relative to the path of the page. For example, if the page is `/example/index.xhtml`, then the script tag would need to look like this:

```xml
<script src="../images.js"/>
```

Finally, within your page use an `<img>` tag with attribute `data-src` to reference the name of a texture in the inventory:

```xml
<img data-src="My Picture"/>
```

When the page is viewed, the Javascript will modify these tags to point to the SL picture-service using the UUID of the texture. For this reason, only full perm textures can be used.
