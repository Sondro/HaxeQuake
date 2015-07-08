package quake;

import js.html.Uint8Array;

@:publicFields
class NETSocket<T> implements INETSocket {
    var disconnected:Bool;
    var address:String;
    var driverdata:T;
	var connecttime:Float;
	var lastMessageTime:Float;
	var driver:Int;

    function new() {
		connecttime = NET.time;
		lastMessageTime = NET.time;
		driver = NET.driverlevel;
		address = 'UNSET ADDRESS';
    }
}

interface INETSocket {
    var disconnected:Bool;
	var driver:Int;
	var lastMessageTime:Float;
}

private typedef NETDriver = {
	var initialized:Bool;
	function Init():Bool;
	function Connect(host:String):INETSocket;
	function CheckNewConnections():INETSocket;
	function Close(sock:INETSocket):Void;
	function CheckForResend():Int;
	function GetMessage(sock:INETSocket):Int;
	function SendMessage(sock:INETSocket, data:MSG):Int;
	function SendUnreliableMessage(sock:INETSocket, data:MSG):Int;
	function CanSendMessage(sock:INETSocket):Bool;
}

@:expose("NET")
@:publicFields
class NET {
	static var activeSockets:Array<INETSocket> = [];
	static var message = new MSG(8192);
	static var activeconnections = 0;
	static var driverlevel:Int;
	static var time:Float;
	static var start_time:Float;
	static var reps:Int;
	static var drivers:Array<NETDriver>;
	static var newsocket:INETSocket;

	static var messagetimeout:Cvar;
	static var hostname:Cvar;

	@:generic
	static function NewQSocket<T:(INETSocket, {function new():Void;})>():T {
		var i = 0;
		while (i < activeSockets.length) {
			if (activeSockets[i].disconnected)
				break;
			i++;
		}
		var sock = new T();
		activeSockets[i] = sock;
		return sock;
	}

	static function Connect(host:String):INETSocket {
		time = Sys.FloatTime();

		if (host == 'local') {
			driverlevel = 0;
			return NET_Loop.Connect(host);
		}

		for (i in 1...drivers.length) {
			driverlevel = i;
			var dfunc = drivers[driverlevel];
			if (dfunc.initialized != true)
				continue;
			var ret = dfunc.Connect(host);
			if ((cast ret) == 0) {
				(untyped CL).cls.state = (untyped CL).active.connecting;
				Console.Print('trying...\n');
				start_time = time;
				reps = 0;
				throw 'NET.Connect';
			}
			if (ret != null)
				return ret;
		}

		return null;
	}

	static function CheckForResend() {
		time = Sys.FloatTime();
		var dfunc = drivers[newsocket.driver];
		if (reps <= 2) {
			if ((time - start_time) >= (2.5 * (reps + 1))) {
				Console.Print('still trying...\n');
				++reps;
			}
		} else if (reps == 3) {
			if ((time - start_time) >= 10.0) {
				Close(newsocket);
				(untyped CL).cls.state = (untyped CL).active.disconnected;
				Console.Print('No Response\n');
				(untyped Host).Error('NET.CheckForResend: connect failed\n');
			}
		}
		var ret = dfunc.CheckForResend();
		if (ret == 1) {
			newsocket.disconnected = false;
			(untyped CL).Connect(newsocket);
		}
		else if (ret == -1) {
			newsocket.disconnected = false;
			Close(newsocket);
			(untyped CL).cls.state = (untyped CL).active.disconnected;
			Console.Print('Network Error\n');
			(untyped Host).Error('NET.CheckForResend: connect failed\n');
		}
	}

	static function CheckNewConnections():INETSocket {
		time = Sys.FloatTime();

		for (i in 0...drivers.length) {
			driverlevel = i;
			var dfunc = drivers[driverlevel];
			if (dfunc.initialized != true)
				continue;
			var ret = dfunc.CheckNewConnections();
			if (ret != null)
				return ret;
		}

		return null;
	}

	static function Close(sock:INETSocket) {
		if (sock == null)
			return;
		if (sock.disconnected)
			return;
		time = Sys.FloatTime();
		drivers[sock.driver].Close(sock);
		sock.disconnected = true;
	}

	static function GetMessage(sock:INETSocket):Int {
		if (sock == null)
			return -1;
		if (sock.disconnected) {
			Console.Print('NET.GetMessage: disconnected socket\n');
			return -1;
		}
		time = Sys.FloatTime();
		var ret = drivers[sock.driver].GetMessage(sock);
		if (sock.driver != 0) {
			if (ret == 0) {
				if ((time - sock.lastMessageTime) > messagetimeout.value) {
					Close(sock);
					return -1;
				}
			}
			else if (ret > 0)
				sock.lastMessageTime = time;
		}
		return ret;
	}

	static function SendMessage(sock:INETSocket, data:MSG):Int {
		if (sock == null)
			return -1;
		if (sock.disconnected) {
			Console.Print('NET.SendMessage: disconnected socket\n');
			return -1;
		}
		time = Sys.FloatTime();
		return drivers[sock.driver].SendMessage(sock, data);
	}

	static function SendUnreliableMessage(sock:INETSocket, data:MSG):Int {
		if (sock == null)
			return -1;
		if (sock.disconnected) {
			Console.Print('NET.SendUnreliableMessage: disconnected socket\n');
			return -1;
		}
		time = Sys.FloatTime();
		return drivers[sock.driver].SendUnreliableMessage(sock, data);
	}

	static function CanSendMessage(sock:INETSocket):Bool {
		if (sock == null)
			return false;
		if (sock.disconnected)
			return false;
		time = Sys.FloatTime();
		return drivers[sock.driver].CanSendMessage(sock);
	}

	static function SendToAll(data:MSG):Int {
		var count = 0, state1 = [], state2 = [];
		for (i in 0...(untyped SV).svs.maxclients) {
			(untyped Host).client = (untyped SV).svs.clients[i];
			if ((untyped Host).client.netconnection == null)
				continue;
			if ((untyped Host).client.active != true) {
				state1[i] = state2[i] = true;
				continue;
			}
			if ((untyped Host).client.netconnection.driver == 0) {
				SendMessage((untyped Host).client.netconnection, data);
				state1[i] = state2[i] = true;
				continue;
			}
			++count;
			state1[i] = state2[i] = false;
		}
		var start = Sys.FloatTime();
		while (count != 0) {
			count = 0;
			for (i in 0...(untyped SV).svs.maxclients) {
				(untyped Host).client = (untyped SV).svs.clients[i];
				if (state1[i] != true) {
					if (CanSendMessage((untyped Host).client.netconnection)) {
						state1[i] = true;
						SendMessage((untyped Host).client.netconnection, data);
					}
					else
						GetMessage((untyped Host).client.netconnection);
					++count;
					continue;
				}
				if (state2[i] != true) {
					if (CanSendMessage((untyped Host).client.netconnection))
						state2[i] = true;
					else
						GetMessage((untyped Host).client.netconnection);
					++count;
				}
			}
			if ((Sys.FloatTime() - start) > 5.0)
				return count;
		}
		return count;
	}

	static function Init():Void {
		time = Sys.FloatTime();

		messagetimeout = Cvar.RegisterVariable('net_messagetimeout', '300');
		hostname = Cvar.RegisterVariable('hostname', 'UNNAMED');

		drivers = [NET_Loop, NET_WEBS];
		for (i in 0...drivers.length) {
			driverlevel = i;
			drivers[driverlevel].initialized = drivers[driverlevel].Init();
		}
	}

	static function Shutdown():Void {
		time = Sys.FloatTime();
		for (i in 0...activeSockets.length)
			Close(activeSockets[i]);
	}
}