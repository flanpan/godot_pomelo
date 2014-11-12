var PKG_HEAD_BYTES = 4;
var MSG_FLAG_BYTES = 1;
var MSG_ROUTE_CODE_BYTES = 2;
var MSG_ID_MAX_BYTES = 5;
var MSG_ROUTE_LEN_BYTES = 1;

var MSG_ROUTE_CODE_MAX = 0xffff;

var MSG_COMPRESS_ROUTE_MASK = 0x1;
var MSG_TYPE_MASK = 0x7;

class Package:
	const TYPE_HANDSHAKE = 1
	const TYPE_HANDSHAKE_ACK = 2
	const TYPE_HEARTBEAT = 3
	const TYPE_DATA = 4
	const TYPE_KICK = 5
	var _parent
	
	func _init(parent):
		_parent = parent
	
	func encode_bak(type,body):
		var length = 0
		if body != null:
			length = body.size()
		var buffer = RawArray()
		buffer.push_back(type)
		buffer.push_back((length>>16)&0xff)
		buffer.push_back((length>>8)&0xff)
		buffer.push_back(length&0xff)
		if body != null:
			for i in range(body.size()):
				buffer.push_back(body.get(i))
	
	func encode(type,body):
		var length 
		if body != null:
			length = body.size()
		else:
			length = 0
		var buffer = RawArray()
		buffer.resize(_parent.PKG_HEAD_BYTES+length)
		var index = 0
		buffer[index] = type & 0xff
		index += 1
		buffer[index] = (length>>16) & 0xff
		index += 1
		buffer[index] = (length >> 8) & 0xff
		index += 1
		buffer[index] = length & 0xff
		index += 1
		if typeof(body) != null:
			buffer = _parent._copyArray(buffer,index,body,0,length)

		return buffer

	
	func decode(buffer):
		var offset = 0
		var bytes = RawArray(buffer)
		var length = 0
		var rs = []
		while offset < bytes.size():
			var type = bytes[offset]
			offset += 1
			length = ((bytes[offset])) << 16
			offset += 1
			length |= (bytes[offset])<<8
			offset += 1
			length |= bytes[offset]
			offset += 1
			#length = length >> 0 # 无符号右移 >>>
			length = abs(length)# >> 0
			var body = null
			if length:
				body = RawArray()
				body.resize(length)
			body = _parent._copyArray(body,0,bytes,offset,length)
			offset += length
			rs.push_back({"type":type,"body":body})
		var res = rs
		if rs.size() == 1:
			res = rs[0]
		return res
		
	
	
class Message:
	const TYPE_REQUEST = 0
	const TYPE_NOTIFY = 1
	const TYPE_RESPONSE = 2
	const TYPE_PUSH = 3
	var _parent
	
	func _init(parent):
		_parent = parent
	
	func encode(id,type,compressRoute,route,msg):
		var idBytes
		if _parent._msgHasId(type):
			idBytes = _parent._caculateMsgIdBytes(id)
		else:
			idBytes = 0
		var msgLen = _parent.MSG_FLAG_BYTES + idBytes
		if _parent._msgHasRoute(type):
			if compressRoute:
				#if route is not number ,error
				msgLen += _parent.MSG_ROUTE_CODE_BYTES
			else:
				msgLen += _parent.MSG_ROUTE_LEN_BYTES
				if route:
					route = _parent.strencode(route)
					if route.length > 255:
						return print("route maxLength is overflow.")
					msgLen += route.length
		if msg:
			msgLen += msg.size()
		var buffer = RawArray()
		buffer.resize(msgLen)
		var offset = 0
		offset = _parent._encodeMsgFlag(type,compressRoute,buffer,offset)
		if _parent._msgHasId(type):
			offset = _parent._encodeMsgId(id,buffer,offset)
		if _parent._msgHasRoute(type):
			offset = _parent._encodeMsgRoute(compressRoute,route,buffer,offset)
		if msg:
			offset = _parent._encodeMsgBody(msg,buffer,offset)
		return buffer

	func decode(buffer):
		var bytes = RawArray(buffer)
		var bytesLen = bytes.size()
		var offset = 0
		var id = 0
		var route = null
		var flag = bytes[offset]
		offset += 1
		var compressRoute = flag & _parent.MSG_COMPRESS_ROUTE_MASK
		var type = (flag >> 1) & _parent.MSG_TYPE_MASK
		if _parent.msgHasId(type):
			var m = int(bytes[offset])
			var i = 0
			
			m = int(bytes[offset])
			id = id + ((m & 0x7f) * pow(2,(7*i)))
			offset += 1
			i += 1
			while m>= 128:
				m = int(bytes[offset])
				id = id + ((m & 0x7f) * pow(2,(7*i)))
				offset += 1
				i += 1
		if _parent._msgHasRoute(type):
			if _parent._msgHasRoute(type):
				if compressRoute:
					route = (bytes[offset]) << 8
					offset += 1
					route |= bytes[offset]
					offset += 1
				else:
					var routeLen = bytes[offset]
					offset += 1
					if routeLen:
						route = RawArray()
						route.resize(routeLen)
						route = _parent._copyArray(route,0,bytes,offset,routeLen)
						route = _parent.strdecode(route)
					else:
						route = ""
					offset += routeLen
		var bodyLen = bytesLen - offset
		var body = RawArray()
		body.resize(bodyLen)
		body = _parent._copyArray(body,0,bytes,offset,bodyLen)

		return {"id":id,"type":type,"compressRoute":compressRoute,"route":route,"body":body}

###########
var package = Package.new(self)
var message = Message.new(self)

func _copyArray(dest,doffset,src,soffset,length):
	for i in range(length):
		dest[doffset+i] = src[soffset+i]
		#print(src[soffset])
	#for i in range(dest.size()):
	#	print(dest.get(i))
	return dest

func _msgHasId(type):
	return type == message.TYPE_REQUEST || type == message.TYPE_RESPONSE

func _msgHasRoute(type) :
	return type == message.TYPE_REQUEST || type == message.TYPE_NOTIFY|| type == message.TYPE_PUSH

func _caculateMsgIdBytes(id):
	var len = 0
	len += 1
	id >>= 7
	while id >0:
		len += 1
		id >>= 7
	return len

func _encodeMsgFlag(type,compressRoute,buffer,offset):
	if type != message.TYPE_REQUEST && type != message.TYPE_NOTIFY && type != message.TYPE_RESPONSE && type != message.TYPE_PUSH:
		return print("unkonw message type.",type)
	var tmp
	if compressRoute:
		tmp = 1
	else:
		tmp = 0
	buffer[offset] = (type << 1) | tmp
	return offset+MSG_FLAG_BYTES

func _encodeMsgId(id,buffer,offset):
	var tmp
	var next
	tmp = id%128
	next = floor(id/128)
	if next != 0:
		tmp = tmp + 128
	buffer[offset] = tmp
	offset += 1
	id = next
	while id != 0:
		tmp = id%128
		next = floor(id/128)
		if next != 0:
			tmp = tmp + 128
		buffer[offset] = tmp
		offset += 1
		id = next
	return offset

func _encodeMsgRoute(compressRoute,route,buffer,offset):
	if compressRoute:
		if route > MSG_ROUTE_CODE_MAX:
			return print("route number is overflow.")
		buffer[offset] = (route>>8) & 0xff
		offset += 1
		buffer[offset] = route & 0xff
		offset +=1
	else:
		if route:
			buffer[offset] = route.lenth & 0xff
			buffer = _copyArray(buffer,offset,route,0,route.length)
			offset += route.length
		else:
			buffer[offset] = 0
			offset += 1
	return offset

func _encodeMsgBody(msg,buffer,offset):
	buffer = _copyArray(buffer,offset,msg,0,msg.size())
	return offset + msg.size()

func strencode_old(s):
	var byteArray = RawArray()
	byteArray.resize(s.length() *3)
	var offset = 0
	for i in range(s.length()):
		var charCode = s.ord_at(i)
		var codes = null
		if charCode <= 0x7f:#127
			codes = [charCode]
		elif charCode <= 0x7ff:#2047
			codes = [0xc0|(charCode>>6),0x80|(charCode & 0x3f)]
		else:
			codes = [0xe0|(charCode>>12),0x80|((charCode & 0xfc0)>>6), 0x80|(charCode & 0x3f)]
		for j in range(codes.size()):
			byteArray[offset] = codes[j]
			offset += 1
	var _buffer = RawArray()
	_buffer.resize(offset)
	_buffer = _copyArray(_buffer,0,byteArray,0,offset)
	return _buffer

func strencode(s):
	var raw = RawArray()
	for i in range(s.length()):
		raw.push_back(s.ord_at(i))
	return raw

func strdecode(buffer):
	return buffer.get_string_from_utf8()
	
func strdecode_old(buffer):
	var bytes = buffer#RawArray()
	var array = RawArray()#[]
	var offset = 0
	var charCode = 0
	var end = bytes.size()
	while offset < end:
		if bytes[offset] < 128:
			charCode = bytes[offset]
			offset += 1
		elif bytes[offset]<224:
			charCode = ((bytes[offset] & 0x3f)<<6) + (bytes[offset+1] & 0x3f)
			offset +=2
		else:
			charCode = ((bytes[offset] & 0x0f)<<12) + ((bytes[offset+1] & 0x3f)<<6) + (bytes[offset+2] & 0x3f)
			offset +=3
		array.push_back(charCode)
		#print(charCode)
	#return String.fromCharCode.apply(null, array);
	return array.get_string_from_ascii()
	#return array.get_string_from_utf8()

