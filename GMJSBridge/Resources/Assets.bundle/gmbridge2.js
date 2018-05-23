window.GMJSBridge={
version:"1.0",
sendCommand:function (commandName) {
    var args=[];
    for(var i=1;i<arguments.length;i++){
        args.push(arguments[i]);
    }
    this._postMsg(commandName,args);
},
addHandler:function (commandName,func) {
    this._event.handlers[commandName]=func;
},
_getCommand:function (commandName) {
    var args=[];
    for(var i=1;i<arguments.length;i++){
        args.push(arguments[i]);
    }
    var func=this._event.handlers[commandName];
    if (typeof func == "string"){
        func=eval(func);
    }
    if (typeof func != "undefined") {
        return func.apply(func,args);
    };
    return null;
},
_event:{
callbacks:[],
addCallback:function (context,callback) {
    this.callbacks.push({"context":context,"callback":callback});
},
fireCallback:function (context,param) {
    var index=-1;
    for (var i = 0; i < this.callbacks.length; i++) {
        if (this.callbacks[i].context==context) {
            var callback=this.callbacks[i].callback;
            if (typeof callback == "function") {
                callback("",param);
            }
            else if (typeof callback == "string") {
                eval(callback)("",param);
            };
            index=i;
            break;
        };
    }
    if (index>-1) {
        this.callbacks.splice(index,1);
    };
},
handlers:{}
},
_complete:function (context,param) {
    GMJSBridge._event.fireCallback(context,param);
},
_getContext:function (commandName) {
    var timestamp=new Date().getTime();
    return commandName+timestamp;
},
_log:function (text) {
    //alert(text);
},
_functionString:function (text) {
    try{
        if(typeof eval(text) == "function") return true;
    }
    catch(err){ // igore err
    }
    return false;
},
_postMsg:function (commandName,args) {
    var context=this._getContext(commandName);
    var b=false;
    if(args.length>0 && ( typeof args[args.length-1] == "function" || this._functionString(args[args.length-1] ))){
        this._event.addCallback(context,args[args.length-1]);
        b=true;
    }
    var params=[];
    params.push(commandName);
    params.push(context);
    params.push("GMJSBridge._complete");
    for (var i = 0; i < args.length-(b?1:0); i++) {
        params.push(args[i]);
    };
    _gm_jsbridge.getCommand.apply(_gm_jsbridge,params);
}
}
window.Report=window.GMJSBridge;
