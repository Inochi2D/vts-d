/*
    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
/**
    VTS API Data Definitions
*/
module vts.data;
import fghj;

/**
    Serializes a request or response
*/
string vtsSerialize(T)(T json) {
    return serializeToJson!T(json);
}

/**
    Deserializes a request or response
*/
T vtsDeserialize(T)(string data) {
    return deserialize!T(parseJson(data));
}

//
//                  REQUESTS
//

struct VTSRequest(T, string type) {

    @serdeKeys("apiName")
    string apiName = "VTubeStudioPublicAPI";

    @serdeKeys("apiVersion")
    string apiVersion = "1.0";

    @serdeKeys("requestID")
    string requestID;

    @serdeKeys("messageType")
    string messageType = type;

    // Do not include data segment if T is void
    static if (!is(T == void)) {
        @serdeKeys("data")
        T data;

        this(string requestID, T data) {
            this.apiName = "VTubeStudioPublicAPI";
            this.apiVersion = "1.0";
            this.requestID = requestID;
            this.data = data;
            this.messageType = type;
        }

        this(ref return scope inout(typeof(this)) src) inout {
            foreach (i, ref inout field; src.tupleof)
                this.tupleof[i] = field;
        }

    } else {
        this(string requestID) {
            this.requestID = requestID;
        }
    }
}

alias VTSAPIStateRequest = VTSRequest!(void, "APIStateRequest");
alias VTSAuthenticationTokenRequest = VTSRequest!(
    VTSAuthenticationTokenRequestData, "AuthenticationTokenRequest");
alias VTSAuthenticationRequest = VTSRequest!(VTSAuthenticationRequestData, "AuthenticationRequest");
alias VTSStatisticsRequest = VTSRequest!(void, "StatisticsRequest");
alias VTSFolderInfoRequest = VTSRequest!(void, "FolderInfoRequest");
alias VTSCurrentModelRequest = VTSRequest!(void, "CurrentModelRequest");
alias VTSAvailableModelsRequest = VTSRequest!(void, "AvailableModelsRequest");
alias VTSModelLoadRequest = VTSRequest!(VTSModelLoadRequestData, "ModelLoadRequest");

//
//                  REQUEST DATA
//

/**
    Protocol:
        {
            "pluginName": "My Cool Plugin",
            "pluginDeveloper": "My Name",
            "pluginIcon": "iVBORw0.........KGgoA="
        }
*/
struct VTSAuthenticationTokenRequestData {

    @serdeKeys("pluginName")
    string pluginName;

    @serdeKeys("pluginDeveloper")
    string pluginDeveloper;

    @serdeKeys("pluginIcon")
    string pluginIcon;

    this(string pluginName, string pluginDeveloper, ubyte[] pluginIcon) {
        import std.base64 : Base64URL;

        this.pluginName = pluginName;
        this.pluginDeveloper = pluginDeveloper;
        this.pluginIcon = Base64URL.encode(pluginIcon);
    }
}

/**
    Protocol:
        {
            "pluginName": "My Cool Plugin",
            "pluginDeveloper": "My Name",
            "authenticationToken": "adcd-123-ef09-some-token-string-abcd"
        }
*/
struct VTSAuthenticationRequestData {

    @serdeKeys("pluginName")
    string pluginName;

    @serdeKeys("pluginDeveloper")
    string pluginDeveloper;

    @serdeKeys("authenticationToken")
    string authenticationToken;
}

/**
    Protocol:
        {
            "modelID": "UniqueIDOfModelToLoad"
        }
*/
struct VTSModelLoadRequestData {

    @serdeKeys("modelID")
    string modelID;
}

//
//                  RESPONSES
//

/**
    Checks the response of a request for an error
*/
bool vtsCheckRequestError(string json) {
    struct req {
        string messageType;
    }

    req r = vtsDeserialize!req(json);
    return r.messageType == "APIError";
}

/**
    Creates a VTSException from a json stream with an APIError
*/
VTSException vtsAPIErrorToException(string json) {
    struct VTSAPIErrorData {
        @serdeKeys("errorID")
        int errorID;

        @serdeKeys("message")
        string message;
    }

    alias VTSAPIError = VTSResponse!(VTSAPIErrorData, "APIError");

    VTSAPIError err = vtsDeserialize!VTSAPIError(json);
    return new VTSException(err.data.errorID, err.data.message);
}

class VTSException : Exception {
    int id;

    this(int errorId, string message) {
        super(message);
        this.id = errorId;
    }

    this(string msg) {
        this(-1, msg);
    }

    override
    string toString() {
        import std.format : format;

        return "%s: %s".format(id, msg);
    }
}

struct VTSResponse(T, string type) {

    @serdeKeys("apiName")
    string apiName = "VTubeStudioPublicAPI";

    @serdeKeys("apiVersion")
    string apiVersion = "1.0";

    @serdeKeys("timestamp")
    long timestamp;

    @serdeKeys("messageType")
    string messageType;

    @serdeKeys("requestID")
    string requestID;

    @serdeKeys("data")
    T data;

    this(ref return scope inout(typeof(this)) src) inout {
        foreach (i, ref inout field; src.tupleof)
            this.tupleof[i] = field;
    }
}

alias VTSAPIStateResponse = VTSRequest!(VTSAPIStateResponseData, "APIStateResponse");
alias VTSAuthenticationTokenResponse = VTSRequest!(VTSAuthenticationTokenResponseData, "AuthenticationTokenResponse");
alias VTSAuthenticationResponse = VTSRequest!(VTSAuthenticationResponseData, "AuthenticationResponse");
alias VTSStatisticsResponse = VTSRequest!(VTSStatisticsResponseData, "StatisticsResponse");
alias VTSFolderInfoResponse = VTSRequest!(VTSFolderInfoResponseData, "FolderInfoResponse");
alias VTSCurrentModelResponse = VTSRequest!(VTSCurrentModelResponseData, "CurrentModelResponse");
alias VTSAvailableModelsResponse = VTSRequest!(VTSAvailableModelsResponseData, "AvailableModelsResponse");
alias VTSModelLoadResponse = VTSRequest!(VTSModelLoadResponseData, "ModelLoadResponse");

/**
    Protocol:
        {
            "positionX": -0.1,
            "positionY": 0.4,
            "rotation": 9.33,
            "size": -61.9
        }
*/
struct VTSModelPosition {

    @serdeKeys("positionX")
    float positionX;

    @serdeKeys("positionY")
    float positionY;

    @serdeKeys("rotation")
    float rotation;

    @serdeKeys("size")
    float size;
}

//
//                  RESPONSE DATA
//

/**
    Protocol:
        {
            "active": true,
            "vTubeStudioVersion": "1.9.0",
            "currentSessionAuthenticated": false
        }
*/
struct VTSAPIStateResponseData {

    @serdeKeys("active")
    bool active;

    @serdeKeys("vTubeStudioVersion")
    string vtsVersion;

    @serdeKeys("currentSessionAuthenticated")
    bool currentSessionAthenticated;
}

/**
    Protocol:
        {
            "authenticationToken": "adcd-123-ef09-some-token-string-abcd"
        }
*/
struct VTSAuthenticationTokenResponseData {

    @serdeKeys("authenticationToken")
    string authenticationToken;
}

/**
    Protocol:
        {
            "authenticated": true,
            "reason": "Token valid. The plugin is authenticated for the duration of this session."
        }
*/
struct VTSAuthenticationResponseData {

    @serdeKeys("authenticated")
    bool authenticated;

    @serdeKeys("reason")
    string reason;
}

/**
    Protocol:
        {
            "uptime": 1439384,
            "framerate": 73,
            "vTubeStudioVersion": "1.9.0",
            "allowedPlugins": 7,
            "connectedPlugins": 2,
            "startedWithSteam": true,
            "windowWidth": 1031,
            "windowHeight": 812,
            "windowIsFullscreen": false
        }
*/
struct VTSStatisticsResponseData {

    @serdeKeys("uptime")
    long uptime;

    @serdeKeys("framerate")
    int framerate;

    @serdeKeys("vTubeStudioVersion")
    string vtsVersion;

    @serdeKeys("allowedPlugins")
    int allowedPlugins;

    @serdeKeys("startedWithSteam")
    bool startedWithSteam;

    @serdeKeys("windowWidth")
    uint windowWidth;

    @serdeKeys("windowHeight")
    uint windowHeight;

    @serdeKeys("windowIsFullscreen")
    bool windowIsFullscreen;
}

/**
    Protocol:
        {
            "models": "Live2DModels",
            "backgrounds": "Backgrounds",
            "items": "Items",
            "config": "Config",
            "logs": "Logs",
            "backup": "Backup"
        }
*/
struct VTSFolderInfoResponseData {

    @serdeKeys("models")
    string models;

    @serdeKeys("backgrounds")
    string backgrounds;

    @serdeKeys("items")
    string items;

    @serdeKeys("logs")
    string logs;

    @serdeKeys("backup")
    string backup;
}

/**
    Protocol:
        {
            "modelLoaded": true,
            "modelName": "My Currently Loaded Model",
            "modelID": "UniqueIDToIdentifyThisModelBy",
            "vtsModelName": "Model.vtube.json",
            "vtsModelIconName": "ModelIconPNGorJPG.png",
            "live2DModelName": "Model.model3.json",
            "modelLoadTime": 3021,
            "timeSinceModelLoaded": 419903,
            "numberOfLive2DParameters": 29,
            "numberOfLive2DArtmeshes": 136,
            "hasPhysicsFile": true,
            "numberOfTextures": 2,
            "textureResolution": 4096,
            "modelPosition": {
                "positionX": -0.1,
                "positionY": 0.4,
                "rotation": 9.33,
                "size": -61.9
            }
        }
*/
struct VTSCurrentModelResponseData {

    @serdeKeys("modelLoaded")
    bool modelLoaded;

    @serdeKeys("modelName")
    string modelName;

    @serdeKeys("modelID")
    string modelID;

    @serdeKeys("vtsModelName")
    string vtsModelName;

    @serdeKeys("vtsModelIconName")
    string vtsModelIconName;

    @serdeKeys("live2DModelName")
    string live2DModelName;

    @serdeKeys("modelLoadTime")
    ulong modelLoadTime;

    @serdeKeys("timeSinceModelLoaded")
    ulong timeSinceModelLoaded;

    @serdeKeys("numberOfLive2DParameters")
    uint numberOfLive2DParameters;

    @serdeKeys("numberOfLive2DArtmeshes")
    uint numberOfLive2DArtmeshes;

    @serdeKeys("hasPhysicsFile")
    bool hasPhysicsFile;

    @serdeKeys("numberOfTextures")
    uint numberOfTextures;

    @serdeKeys("textureResolution")
    uint textureResolution;

    @serdeKeys("modelPosition")
    VTSModelPosition position;
}

/**
    Protocol:
        "data": {
            "numberOfModels": 2,
            "availableModels": [
                {
                    "modelLoaded": false,
                    "modelName": "My First Model",
                    "modelID": "UniqueIDToIdentifyThisModelBy1",
                    "vtsModelName": "Model_1.vtube.json",
                    "vtsModelIconName": "ModelIconPNGorJPG_1.png"
                },
                {
                    "modelLoaded": true,
                    "modelName": "My Second Model",
                    "modelID": "UniqueIDToIdentifyThisModelBy2",
                    "vtsModelName": "Model_2.vtube.json",
                    "vtsModelIconName": "ModelIconPNGorJPG_1.png"
                }
            ]
        }
*/
struct VTSAvailableModelsResponseData {

    @serdeKeys("numberOfModels")
    uint numberOfModels;

    @serdeKeys("availableModels")
    VTSAvailableModel[] availableModels;
}

/**
    Protocol:
        {
            "modelLoaded": false,
            "modelName": "My First Model",
            "modelID": "UniqueIDToIdentifyThisModelBy1",
            "vtsModelName": "Model_1.vtube.json",
            "vtsModelIconName": "ModelIconPNGorJPG_1.png"
        }
*/
struct VTSAvailableModel {

    @serdeKeys("modelLoaded")
    bool modelLoaded;

    @serdeKeys("modelName")
    string modelName;

    @serdeKeys("modelID")
    string modelId;

    @serdeKeys("vtsModelName")
    string vtsModelName;

    @serdeKeys("vtsModelIconName")
    string vtsModelIconName;
}

/**
    Protocol:
        {
            "modelID": "UniqueIDOfModelThatWasJustLoaded"
        }
*/
struct VTSModelLoadResponseData {

    @serdeKeys("modelID")
    string modelID;
}
