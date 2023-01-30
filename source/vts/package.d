/*
    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
/**
    VTube Studio Plugin Integration
*/
module vts;
import vibe.http.websockets;
import vibe.core.stream;
import vibe.inet.url;
import std.format;
public import vts.data;
import std.datetime;
debug(verbose) import std.stdio : writeln;

alias PluginInfo = VTSAuthenticationTokenRequestData;

/**
    A VTube Studio Plugin
*/
class VTSPlugin {
private:
    PluginInfo info;
    string ip;
    ushort port;
    WebSocket socket;
    string reqId;

    string token;
    bool authenticated;

    typeof(Response.data)* sendRequest(Request, Response)(typeof(Request.data) request, Duration timeout=5.seconds) if (__traits(hasMember, Request, "data") && __traits(hasMember, Response, "data")) {
        auto req = Request(reqId, request);
        debug(verbose) writeln(req);
        return &sendRequest_!(Request, Response)(req, timeout).data;
    }

    typeof(Response.data)* sendRequest(Request, Response)(Duration timeout=5.seconds) if (!__traits(hasMember, Request, "data") && __traits(hasMember, Response, "data")) {
        auto req = Request(reqId);
        debug(verbose) writeln(req);
        return &sendRequest_!(Request, Response)(req, timeout).data;
    }

    Response* sendRequest(Request, Response)(typeof(Request.data) request, Duration timeout=5.seconds) if (__traits(hasMember, Request, "data") && !__traits(hasMember, Response, "data")) {
        auto req = Request(reqId, request);
        debug(verbose) writeln(req);
        return sendRequest_!(Request, Response)(req, timeout);
    }

    Response* sendRequest(Request, Response)(Duration timeout=5.seconds) if(!__traits(hasMember, Request, "data") && !__traits(hasMember, Response, "data")) {
        auto req = Request(reqId);
        debug(verbose) writeln(req);
        return sendRequest_!(req, Response)(request, timeout);
    }

    Response* sendRequest_(Request, Response)(Request request, Duration timeout=5.seconds) {
        socket.send(vtsSerialize(request));
        string rid = "";
        Response res;

        // We more or less want to skip requests not for our ID.
        // Therefore if the ID doesn't match we'll retry
        do {
            this.ensureConnected();

            // Try waiting for data
            if (!socket.waitForData(timeout)) return null;


            // Receive the data
            string response = socket.receiveText();

            // Throw exception if API returns error
            if (vtsCheckRequestError(response)) {
                throw vtsAPIErrorToException(response);
            }

            // Deserialize and update response id
            res = vtsDeserialize!Response(response);
            rid = res.requestID;
        } while (rid != this.reqId);

        return new Response(res);
    }

    void generateReqId() {
        import std.base64 : Base64URL;
        import std.random : uniform, choice;
        string valid = "0123456789ABCEDFGHIJKLMOPQRSTUVXYZabcdefghijklmopqrstuvwxyz";
        char[32] rnd;
        foreach(i; 0..rnd.length) {
            rnd[i] = cast(char)choice(cast(ubyte[])valid);
        }

        this.reqId = (cast(string)rnd).dup;
    }

    void ensureConnected() {
        if (!isConnected()) {

            throw new VTSException("Plugin is not connected to VTube Studio");
        }
    }

    void ensureAuthenticated() {
        import std.exception : enforce;
        this.ensureConnected();
        enforce(authenticated, new VTSException("Plugin is not authourized"));
    }

public:

    /**
        On destruction close the socket
    */
    ~this() {
        if(isConnected()) this.disconnect();
    }

    /**
        Constructs a new plugin
    */
    this(PluginInfo info, string ip, ushort port=8001) {
        this.ip = ip;
        this.port = port;
        this.info = info;
        this.generateReqId();
        this.connect();
    }

    /**
        Connects to the API
    */
    void connect() {
        if (!this.isConnected()) socket = connectWebSocket(URL("ws://%s:%u".format(ip, port)));
    }

    /**
        Close the socket
    */
    void disconnect() {
        if (this.isConnected()) {
            socket.close();
            socket = null;
        }
    }

    /**
        Try to reconnect to the API and try to reuse stored token

        Returns true if connection succeeded AND the token could be re-used
    */
    bool reconnect() {
        this.disconnect();
        this.connect();

        if (authenticated && token) {
            try {
                this.login(token);
            } catch (VTSException ex) {
                return false;
            }
            return true;
        }
        return false;
    }

    /**
        Gets whether the plugin has a connection to VTube Studio
    */
    bool isConnected() {
        return socket && socket.connected();
    }

    /**
        Gets whether the plugin is authorized to do priviledged actions.

        If not authorized some endpoints will trigger an exception.
    */
    bool isAuthenticated() {
        return authenticated;
    }

    /**
        Runs an update step, consuming any incoming events if any was found
    */
    void update() {
        
        // Skip update step if we're not connected to VTS
        if (!isConnected() || !authenticated) return;

        while(socket.dataAvailableForRead()) {

        }
    }

    /**
        Attempts to connect to VTS
        If token is specified an attempt will be made to authenticate with that token
    */
    void login(string token=null) {
        if (!isConnected()) {
            this.connect();
        }

        if (token) {
            auto response = this.authenticate(token);
            if (!response.authenticated) throw new VTSException(response.reason);
        } else {
            auto response = this.requestToken(this.info);
            this.authenticate(response.authenticationToken);
        }
    }

    /**
        Gets the current session token for the plugin
    */
    string getCurrentToken() {
        return token;
    }

    /**
        Requests state information from VTube Studio
    */
    VTSAPIStateResponseData requestStateInfo() {
        this.ensureConnected();
        return *this.sendRequest!(VTSAPIStateRequest, VTSAPIStateResponse)();
    }

    /**
        Request a token from VTS
    */
    VTSAuthenticationTokenResponseData requestToken(PluginInfo info) {
        this.ensureConnected();
        auto response = this.sendRequest!(VTSAuthenticationTokenRequest, VTSAuthenticationTokenResponse)(info, Duration.max);
        this.info = info;
        return *response;
    }

    /**
        Authenticate with a token from VTS
    */
    VTSAuthenticationResponseData authenticate(string token) {
        this.ensureConnected();
        auto response = this.sendRequest!(VTSAuthenticationRequest, VTSAuthenticationResponse)(VTSAuthenticationRequestData(
            info.pluginName, 
            info.pluginDeveloper, 
            token
        ));
        this.authenticated = response.authenticated;
        if (!response.authenticated) throw new VTSException(-1, response.reason);
        return *response;    
    }

    /**
        **Requires Authentication**

        Get statistics about currently running VTube Studio instance
    */
    VTSStatisticsResponseData getStatistics() {
        this.ensureAuthenticated();
        return *this.sendRequest!(VTSStatisticsRequest, VTSStatisticsResponse)();
    }

    /**
        **Requires Authentication**

        Get statistics about currently running VTube Studio instance
    */
    VTSFolderInfoResponseData getFolderInfo() {
        this.ensureAuthenticated();
        return *this.sendRequest!(VTSFolderInfoRequest, VTSFolderInfoResponse)();
    }

    /**
        **Requires Authentication**

        Gets information about the currently loaded model
    */
    VTSCurrentModelResponseData getCurrentModel() {
        this.ensureAuthenticated();
        return *this.sendRequest!(VTSCurrentModelRequest, VTSCurrentModelResponse)();
    }

    /**
        **Requires Authentication**

        Gets list of available Models
    */
    VTSAvailableModel[] getModels() {
        this.ensureAuthenticated();
        return this.sendRequest!(VTSAvailableModelsRequest, VTSAvailableModelsResponse)().availableModels.dup;
    }

    /**
        **Requires Authentication**

        Tries to load the model with the specified ID
        Use `getModels()` to get a list of loadable models

        Returns `true` if the model loaded corrosponds to the requested model
        Returns false if not, throws an Exception if an error occured.
    */
    bool tryLoadModel(string id) {
        this.ensureAuthenticated();
        return this.sendRequest!(VTSModelLoadRequest, VTSModelLoadResponse)(VTSModelLoadRequestData(id)).modelID == id;
    }
}