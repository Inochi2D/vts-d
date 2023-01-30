module vts;
import vibe.http.websockets;
import vibe.core.stream;
import vibe.inet.url;
import std.format;
public import vts.data;
import std.datetime;
debug(verbose) import std.stdio : writeln;

alias PluginInfo = VTSAuthenticationTokenRequestData;

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

    typeof(Response.data)* sendRequest(Request, Response)(Request request, Duration timeout=5.seconds) if (!__traits(hasMember, Request, "data") && __traits(hasMember, Response, "data")) {
        debug(verbose) writeln(request);
        request.requestID = reqId;
        return &sendRequest_!(Request, Response)(request, timeout).data;
    }

    Response* sendRequest(Request, Response)(typeof(Request.data) request, Duration timeout=5.seconds) if (__traits(hasMember, Request, "data") && !__traits(hasMember, Response, "data")) {
        auto req = Request(reqId, request);
        debug(verbose) writeln(req);
        return sendRequest_!(Request, Response)(req, timeout);
    }

    Response* sendRequest(Request, Response)(Request request, Duration timeout=5.seconds) if(!__traits(hasMember, Request, "data") && !__traits(hasMember, Response, "data")) {
        debug(verbose) writeln(request);
        request.requestID = reqId;
        return sendRequest_!(Request, Response)(request, timeout);
    }

    Response* sendRequest_(Request, Response)(Request request, Duration timeout=5.seconds) {
        socket.send(vtsSerialize(request));
        string rid = "";
        Response res;

        // We more or less want to skip requests not for our ID.
        // Therefore if the ID doesn't match we'll retry
        do {

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
    }

    /**
        Close the socket
    */
    void disconnect() {
        socket.close();
    }

    /**
        Gets whether the plugin has a connection to VTube Studio
    */
    bool isConnected() {
        return socket.connected();
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
    void connect(string token=null) {
        socket = connectWebSocket(URL("ws://%s:%u".format(ip, port)));
        if (socket.connected()) {
            if (token) {
                auto response = this.authenticate(token);
                if (!response.authenticated) throw new VTSException(-1, response.reason);
            } else {
                auto response = this.requestToken(this.info);
                this.authenticate(response.authenticationToken);
            }
        }
    }

    /**
        Gets the current session token for the plugin
    */
    string getCurrentToken() {
        return token;
    }

    /**
        Request a token from VTS
    */
    VTSAuthenticationTokenResponseData requestToken(PluginInfo info) {
        auto response = this.sendRequest!(VTSAuthenticationTokenRequest, VTSAuthenticationTokenResponse)(info, Duration.max);
        this.info = info;
        return *response;
    }

    /**
        Authenticate with a token from VTS
    */
    VTSAuthenticationResponseData authenticate(string token) {
        auto response = this.sendRequest!(VTSAuthenticationRequest, VTSAuthenticationResponse)(VTSAuthenticationRequestData(
            info.pluginName, 
            info.pluginDeveloper, 
            token
        ));
        this.authenticated = response.authenticated;
        if (!response.authenticated) throw new VTSException(-1, response.reason);
        return *response;    
    }
}