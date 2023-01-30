# VTube Studio Bindings for D

This repository contains bindings for the VTube Studio websocket API.

To use the library create a VTSPlugin instance and use the functions it provides to access the API

```d
    VTSPlugin plugin = new VTSPlugin(PluginInfo("Test", "Luna the Foxgirl", null), "127.0.0.1");
    plugin.connect();

    while(plugin.isConnected()) {
        Thread.sleep(100.msecs);
    }

    plugin.disconnect();
```