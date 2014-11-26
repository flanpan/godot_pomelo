extends Node

var socket = StreamPeerTCP.new()
var _connected = false
var protobuf = load("res://pomelo_protobuf.gd").new() 
var protocol = load("res://pomelo_protocol.gd").new()
var package = protocol.package
var message = protocol.message
var heartbeatInterval = 1000
var heartbeatTimeout = 2000
var gapThreshold = 100
var protoVersion
var clientProtos
var abbrs = {}
var serverProtos = {}
var _dict = {}
var nextHeartbeatTimeout
var reqId = 0

const ST_HEAD = 1
const ST_BODY = 2
const ST_CLOSED = 3
const headSize = 4

var headOffset = 0
var packageOffset = 0
var packageSize = 0
var packageBuffer = RawArray()
var state = ST_HEAD
var headBuffer = RawArray()
var lastServerTick = OS.get_ticks_msec()
var lastClientTick = OS.get_ticks_msec()
#var onMap = {}
var signals = {}
var callbacks = {}
var routeMap = {}
var handshakeBuffer = {
	    sys= {
	      type="js-websocket",
	      version= "0.0.1",
	      rsa={}
	    },
	    user={}
	}
var rsa #window.rsa
var localStorage = ConfigFile.new()
var useCrypto
var routes = {}

const ERR = 1
var data

func _ready():
	headBuffer.resize(4)
	var err = localStorage.load("res://user_config.cfg")
	if err:
		return print("load user config error. code:",err)
	add_user_signal("error")
	set_process(true)

func on(event,instance,method):
	connect(event,instance,method)
	
func _process(delta):
	var connected = socket.is_connected()
	if(not connected):
		return
	if (OS.get_ticks_msec() - lastServerTick) > (heartbeatInterval+gapThreshold):
		#print("server heartbeat timeout")
		#emit_signal("heartbeat timeout")
		#return disconnect()
		pass
	
	if(OS.get_ticks_msec() - lastClientTick >= heartbeatInterval):
		#print("client heart beat.")
		#var obj = package.encode(package.TYPE_HEARTBEAT)
		#_send(obj)
		pass
	
	var output = socket.get_partial_data(1024)
	var errCode = output[0]
	var outputData = output[1]
	#print(output)
	if(errCode != 0):
		return print( "receive ErrCode:" + str(errCode)+"|||", ERR)
	#var outStr = outputData.get_string_from_utf8()
	#if(outStr == ""):
	if(not outputData.size()):
		return
	var chunk = outputData
	var offset = 0
	var end=chunk.size()
	#print('recv data size ',end)
	if state==ST_HEAD and packageBuffer == null and not _checkTypeData(chunk[0]):
		print("invalid head message")
		return
	while offset<end:
		if state == ST_HEAD:
			offset = _readHead(chunk,offset)
		if state==ST_BODY:
			offset = _readBody(chunk,offset)

func _checkTypeData(data):
	return data== package.TYPE_HANDSHAKE || data == package.TYPE_HANDSHAKE_ACK || data == package.TYPE_HEARTBEAT || data==package.TYPE_DATA || data==package.TYPE_KICK

func _getBodySize():
	var len = 0
	for i in [1,2,3]:
		if i>1:
			len <<= 8
		#print(i,headBuffer.size())
		len += headBuffer.get(i)#headBuffer.readUInt8(i)
	return len

func _readHead(data,offset):
	var hlen = headSize - headOffset
	var dlen = data.size() - offset
	var len = min(hlen,dlen)
	var dend = offset + len
	#data.copy(headBuffer,headOffset,offset,dend)
	for i in range(len):
		headBuffer.set(headOffset+i,data.get(offset+i))
		#print("set head buffer",headOffset+i,data.get(offset+i))
	headOffset += len
	if headOffset == headSize:
		var size = _getBodySize()
		if size < 0:
			return print("invalid body size.%d",size)
		packageSize = size+headSize
		#packageBuffer = Buffer.new(packageSize)
		#headBuffer.copy(packageBuffer,0,0,headSize)
		packageBuffer.resize(packageSize)
		for i in range(headSize):
			packageBuffer.set(i,headBuffer.get(i))
		packageOffset = headSize
		state = ST_BODY
	return dend

func _readBody(data,offset):
	var blen = packageSize - packageOffset
	var dlen = data.size() - offset
	var len = min(blen,dlen)
	var dend = offset + len
	#data.copy(packageBuffer,packageOffset,offset,dend)
	for i in range(len):
		packageBuffer.set(packageOffset+i,data.get(offset+i))
	packageOffset += len
	if packageOffset == packageSize:
		var buffer = packageBuffer
		_onmessage(buffer)
		_reset()
	return dend

func _reset():
	headOffset = 0
	packageOffset = 0
	packageSize = 0
	packageBuffer.resize(0)
	state = ST_HEAD

func _deCompose(msg):
	var route = str(msg.route)
	if msg.compressRoute:
		if not abbrs.has(route):
			#print('aaaaaaaaaa',typeof(route),abbrs.to_json())
			return {}
		route = abbrs[route]
		msg.route = abbrs[route]
	if serverProtos!=null and serverProtos.has(route):
		return protobuf.decode(route,msg.body)
	else:
		var tmp = {}
		tmp.parse_json(protocol.strdecode(msg.body))
		return tmp
	return msg

func _decode(data):
	#print('_decode 0:',data.size())
	var msg = message.decode(data)
	#print('_decode 1: ',msg.to_json())
	if msg.id >0:
		msg.route = routeMap[int(msg.id)]
		routeMap.erase(int(msg.id))
		if not msg.route:
			return
	msg.body = _deCompose(msg)
	#print('_decode 2: ',msg.to_json())
	return msg


func _onopen():
	var buf = protocol.strencode(handshakeBuffer.to_json())
	var obj = package.encode(package.TYPE_HANDSHAKE,buf)
	#for i in range(obj.size()):
	#	print(obj.get(i))
	_send(obj)

func _onmessage(data):
	lastServerTick = OS.get_ticks_msec()
	_processPackage(package.decode(data))
	#if heartbeatTimeout:
	#	nextHeartbeatTimeout = OS.get_ticks_msec() + heartbeatTimeout
	
	
func _onerror():
	emit_signal("io-error")
	print("socket error.")
	
func _onclose():
	emit_signal("close")
	emit_signal("disconnect")
	print("socket close.")
	
func init(host, port):
	print("pomelo init")
	#user 数据
	#return _initSocket(host,port)
	print("connect to",host,':',port)
	if(localStorage.has_section_key("pomelo","protos") and protoVersion==0):
		var protos = {}.parse_json(localStorage.get_value("pomelo","protos") )
		if not protoVersion:
			protoVersion = 0
		if protos.server:
			serverProtos = protos.server
		else:
			serverProtos = {}
		if protos.client:
			clientProtos = protos.client
		else:
			clientProtos = {}
		if protobuf:
			protobuf.init({encoderProtos=clientProtos,decoderProtos=serverProtos})
	handshakeBuffer.sys.protoVersion = protoVersion
	var err = socket.connect(host, port)
	_connected = socket.is_connected()
	if _connected:
		_onopen()
	return err

func _connect(host,port):
	return socket.connect(host, port)

func disconnect():
	_connected = false
	socket.disconnect()

func request(route,msg,obj,method):
	if(not _connected):
		return print("pomelo have not connect.")
	reqId = reqId+1
	_sendMessage(reqId,route,msg)
	callbacks[reqId] = {}
	callbacks[reqId].instance = obj
	callbacks[reqId].f = method
	routeMap[reqId] = route

func notify(route,msg):
	if not msg:
		msg = {}
	_sendMessage(0,route,msg)
	
func _sendMessage(reqId,route,msg):
	if useCrypto:
		return print("no imp crypto now")
	var type = message.TYPE_NOTIFY
	if reqId:
		type = message.TYPE_REQUEST
	
	if clientProtos!=null and clientProtos.has(route):
		msg = protobuf.encode(route,msg)
	else:
		msg = protocol.strencode(msg.to_json())
	
	var compressRoute = 0
	if _dict != null and _dict.has("route"):
		route = _dict[route]
		compressRoute = 1
	msg = message.encode(reqId,type,compressRoute,route,msg)
	var packet = package.encode(package.TYPE_DATA,msg)
	_send(packet)
	
	
func _send(msg):
	#for i in range(msg.size()):
	#	print(msg.get(i))
	socket.put_partial_data(msg)
	lastClientTick = OS.get_ticks_msec()

func _handshake(data):
	var res = {}
	res.parse_json(protocol.strdecode(data))
	data = res
	if data.code == 501:
		emit_signal("error","client version not fullfill")
		return
	if data.code != 200:
		emit_signal("error","handshake fail.")
		return
	heartbeatInterval = 0
	heartbeatTimeout = 0
	if data.sys != null:
		if data.sys.has("heartbeat"):
			if data.sys.heartbeat !=0:
				heartbeatInterval = data.sys.heartbeat*1000
				heartbeatTimeout = heartbeatInterval*2
	_initData(data)
	var obj = package.encode(package.TYPE_HANDSHAKE_ACK);
	_send(obj)
	emit_signal("init",socket)

func _onData(data):
	var msg = data
	#if _decode:
	msg = _decode(msg)
	_processMessage(msg)

func _onKick(data):
	var res = {}
	res.parse_json(protocol.strdecode(data))
	emit_signal("onKick",data) 
	

func _handlers(type,body):
	if type == package.TYPE_HANDSHAKE:
		_handshake(body)
	elif type == package.TYPE_HEARTBEAT:
		if not heartbeatInterval:
			#servertick
			return
	elif type == package.TYPE_DATA:
		_onData(body)
	elif type == package.TYPE_KICK:
		_onKick(body)
	else:
		pass

func _processPackage(msgs):
	if typeof(msgs) == TYPE_ARRAY:
		for i in msgs:
			var msg = msgs[i]
			_handlers(msg.type,msg.body)
	else:
		_handlers(msgs.type,msgs.body)

func _processMessage(msg):
	#print(msg.to_json())
	if not msg.has('id') or not msg.id:
		return emit_signal(str(msg.route),msg.body)
	var cb = callbacks[msg.id]
	var f = FuncRef.new()
	f.set_instance(cb.instance)
	f.set_function(cb.f)
	callbacks.erase(msg.id)
	f.call_func(msg.body)
	return

func _initData(data):
	if data == null  or  data.sys == null:
		return
	if not data.sys.has("dict"):
		return
	if not data.sys.has("protos"):
		return
	_dict = data.sys["dict"]
	var protos = data.sys.protos
	if _dict != null:
		abbrs = {}
		for route in _dict:
			abbrs[_dict[route]] = route
	if protos != null :
		if protos.version:
			protoVersion = protos.version
		else:
			protoVersion = 0
		if protos.server != null:
			serverProtos = protos.server
		else:
			serverProtos = {}
		if protos.client != null:
			clientProtos = protos.client
		else:
			clientProtos = {}
		if protobuf != null:
			var d = {encoderProtos=protos.client,decoderProtos=protos.server}
			protobuf.init(d)
		localStorage.set_value("pomelo","protos",protos.to_json())
	localStorage.save('res://user_config.cfg')
