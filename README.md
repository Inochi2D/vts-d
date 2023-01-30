# VTube Studio Bindings for D

This repository contains bindings for the VTube Studio websocket API.

To use the library create a VTSPlugin instance and use the functions it provides to access the API


## Example (Change model every 5 seconds)
```d
module app;

import vts;
import std.datetime;
import std.stdio : writeln;
import std.random : choice;
import vibe.core.core : sleep;

void main() {
    VTSPlugin plugin = new VTSPlugin(PluginInfo("Test", "Me", null), "127.0.0.1");
    plugin.login();

    auto models = plugin.getModels();
    do {
        if (models.length > 0) plugin.tryLoadModel(choice(models).modelId);
        
        sleep(5.seconds);
    } while(plugin.isConnected());

    plugin.disconnect();
}
```

## Known Issues
 * If VTube Studio is closed the application will segfault, some bug deep within vibe-d is causing it.