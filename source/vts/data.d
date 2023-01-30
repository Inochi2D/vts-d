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
alias VTSAuthenticationTokenRequest = VTSRequest!(VTSAuthenticationTokenRequestData, "AuthenticationTokenRequest");
alias VTSAuthenticationRequest = VTSRequest!(VTSAuthenticationRequestData, "AuthenticationRequest");

//
//                  REQUEST DATA
//

/**
    Protocol:
        "data": {
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
        "data": {
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

//
//                  RESPONSE DATA
//

/**
    Protocol:
        "data": {
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
        "data": {
            "authenticationToken": "adcd-123-ef09-some-token-string-abcd"
        }
*/
struct VTSAuthenticationTokenResponseData {

    @serdeKeys("authenticationToken")
    string authenticationToken;
}

/**
    Protocol:
        "data": {
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