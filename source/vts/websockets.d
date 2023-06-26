/*
    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Grillo del Mal
*/
module vts.websockets;

import vibe.http.websockets;
import vibe.inet.url;

import core.thread;
import core.sync.mutex;
import core.sync.event;
import std.container : DList;
import std.typecons : Tuple;

class SafeTextQueue {
private:
    Mutex mtx;
    Event textExists;
    DList!string textQueue;
    int textQueueLen;

public:
    this() {
        mtx = new Mutex();
        textQueue = DList!string();
        textQueueLen = 0;
        textExists.initialize(true, false);
    }

    void enqueue(string response) {
        mtx.lock();
        textQueue.insertBack(response);
        textQueueLen ++;
        scope(exit) mtx.unlock();
        textExists.set();
    }
    
    bool isEmpty(){
        mtx.lock();
        scope(exit) mtx.unlock();
        return textQueueLen == 0;
    }

    bool waitForData(Duration timeout=5.seconds) {
        mtx.lock();
        if(textQueueLen == 0){
            textExists.reset();
            mtx.unlock();
            if(!textExists.wait(timeout)){
                return false;
            }
        }
        else{
            mtx.unlock();
        }
        return true;
    }

    string dequeue() {
        string data;
        mtx.lock();
        if( textQueueLen > 0 ){
            data = textQueue.front();
            textQueueLen --;
            textQueue.removeFront();
        }
        scope(exit) mtx.unlock();
        return data;
    }
}

SimpleWebSocket connectSimpleWebSocket(URL url){
    SimpleWebSocket socket = new SimpleWebSocket(url);
    socket.open();
    return socket;
}

class SimpleWebSocket {
private:
    bool isCloseRequested;
    Thread receivingThread;

    SafeTextQueue recvQueue;
    SafeTextQueue sendQueue;

    URL serverUrl;

    void handleConnection(scope WebSocket socket) {
        while (!isCloseRequested && socket.connected) {
            try {
                if(!sendQueue.isEmpty()) {
                    socket.send(sendQueue.dequeue());
                }

                ptrdiff_t received = socket.waitForData(16.msecs);
                if (received <= 0) {
                    continue;
                }

                auto text = socket.receiveText();
                recvQueue.enqueue(text);
            } catch (Exception ex) {
                Thread.sleep(100.msecs);
            }
        }
    }

    void receiveThread() {
        isCloseRequested = false;
        vibe.http.websockets.connectWebSocket(serverUrl, &this.handleConnection);
    }

protected:
    this(URL url){
        serverUrl = url;
        sendQueue = new SafeTextQueue();
        recvQueue = new SafeTextQueue();
    }
    
    void open(){
        receivingThread = new Thread(&receiveThread);
        receivingThread.start();
    }

public:
    void close() {
        isCloseRequested = true;
        receivingThread.join(false);
        receivingThread = null;
    }

    bool connected() {
        return receivingThread !is null && receivingThread.isRunning();
    }

    bool dataAvailableForRead() {
        return !recvQueue.isEmpty();
    }

    string receiveText() {
        return recvQueue.dequeue();
    }

    bool waitForData(Duration timeout=5.seconds) {
        return recvQueue.waitForData(timeout);
    }

    void send(string data) {
        sendQueue.enqueue(data);
    }
}
