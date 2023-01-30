# VTube Studio Bindings for D

This repository contains bindings for the VTube Studio websocket API.

To use the library create a VTSPlugin instance and use the functions it provides to access the API


## Example (Change model every 5 seconds)
```d
module app;

import vts;
import core.thread;
import std.datetime;
import std.stdio : writeln;
import std.random : choice;

void main() {
    VTSPlugin plugin = new VTSPlugin(PluginInfo("Test", "Me", null), "127.0.0.1");
    plugin.login();

    auto models = plugin.getModels();
    do {
        if (models.length > 0) plugin.tryLoadModel(choice(models).modelId);
        
        Thread.sleep(5.seconds);
    } while(plugin.isConnected());

    plugin.disconnect();
}
```