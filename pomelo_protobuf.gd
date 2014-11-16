var constant = {
	"uInt32": 0,
	"sInt32": 0,
	"int32": 0,
	"double": 1,
	"string": 2,
	"message": 2,
	"float": 5
}

class Util:
	static func isSimpleType(type):
		return (type == "uInt32" || type == "sInt32" || type == "int32" || type=="uInt64" || type=="sInt64" || type=="float" || type=="double")

class Encoder:
	var codec
	var protos
	var constant
	var util

	func _init(codec,constant,util):
		self.codec = codec
		self.constant = constant
		self.util = util

	func init(protos):
		self.protos = protos
		if(self.protos == null):
			self.protos = {}

	func encode(route,msg):
		var protos
		if self.protos.has(route):
			protos = self.protos[route]
		if not checkMsg(msg,protos):
			return null
		var length = codec.byteLength({}.to_json(msg))
		var buffer = RawArray()
		buffer.resize(length)
		var uInt8Array = RawArray(buffer)
		var offset = 0
		if protos != null:
			offset = encodeMsg(uInt8Array,offset,protos,msg)
			if offset>0:
				var arr = RawArray()
				for i in range(offset):
					arr.push_back(uInt8Array[i])
				return arr
		return null

	func checkMsg(msg,protos):
		if protos == null:
			return false
		for name in protos:
			var proto = protos[name]
			if proto.option == "required":
				if not msg.has(name):
					print("no property exist for required,name:%s",name)
					return false
			elif proto.option == "optional":
				if not msg.has(name):
					var message = protos.__message[proto.type] || self.protos["message "+proto.type]
					if message != null && !checkMsg(msg[name],message):
						print("inner proto error! name:%s",name)
						return false
			elif proto.option == "repeated":
				var message = protos.__message[proto.type]||self.protos["message "+proto.type]
				if msg.has(name) && message != null:
					for i in msg[name]:
						if not checkMsg(msg[name][i],message):
							return false
		return true

	func encodeMsg(buffer,offset,protos,msg):
		for name in msg:
			if protos.has(name):
				var proto = protos[name]
				if proto.option == "required" || proto.option == "optional":
					offset = writeBytes(buffer,offset,encodeTag(proto.type,proto.tag))
					offset = encodeProp(msg[name],proto.type,offset,buffer,protos)
				elif proto.option == "repeated":
					if msg[name].size() >0:
						offset = encodeArray(msg[name],proto,offset,buffer,protos)
		return offset

	func encodeProp(value,type,offset,buffer,protos):
		pass

	func encodeArray(array,proto,offset,buffer,protos):
		pass

	func writeBytes(buffer,offset,bytes):
		pass

	func encodeTag(type,tag):
		var value = constant[type]||2
		return codec.encodeUInt32((tag<<3)|value)

class Decoder:
	var codec
	var protos
	var constant
	var util
	var offset = 0
	var buffer

	func _init(codec,constant,util):
		self.codec = codec
		self.constant = constant
		self.util = util

	func init(protos):
		self.protos = protos
		if(self.protos == null):
			self.protos = {}

	func decode(key,msg):
		pass

	func decodeMsg(msg,protos,length):
		pass

	func getHead():
		pass

	func peekHead():
		pass

	func decodeProp(type,protos):
		pass

	func decodeArray(array,type,protos):
		if util.isSimpleType(type):
			var length = codec.decodeUInt32(getBytes())
			for i in length:
				array.push(decodeProp(type))
		else:
			array.push(decodeProp(type,protos))
		return array

	func getBytes(flag):
		var bytes = []
		var pos = offset
		flag = flag || false
		var b
		b = buffer[pos]
		bytes.push(b)
		pos+=1
		while b>= 128:
			b = buffer[pos]
			bytes.push(b)
			pos+=1
		if not flag:
			offset = pos
		return bytes

	func peekBytes():
		return getBytes(true)

class Codec:
	var buffer = RawArray()
	var float32Array
	var float64Array
	var uInt8Array

	func _init():
		buffer.resize(8)
		float32Array = []#RealArray.new()
		float64Array = []#RealArray.new()
		uInt8Array = RawArray(buffer) 

	func encodeUInt32(n):
		var n = int(n)
		var result = []
		var tmp = n%128
		var next = floor(n/128)
		if next != 0:
			tmp = tmp + 128
		result.push(tmp)
		n = next
		while n!=0:
			tmp = n%128
			next = floor(n/128)
			if next != 0:
				tmp = tmp + 128
			result.push(tmp)
			n = next
		return result

	func encodeSInt32(n):
		var n = int(n)
		n = n*2
		if n<0:
			n = abs(n)*2-1
		return encodeUInt32(n)

	func decodeUInt32(bytes):
		var n = 0
		for i in range(bytes.size()):
			var m = int(bytes[i])
			n = n+(m&0x7f)*pow(2,(7*i))
			if m<128:
				return n
		return n

	func decodeSInt32(bytes):
		var n = decodeUInt32(bytes)
		var flag = 1
		if (n%2) == 1:
			flag = -1
		n = ((n%2 + n)/2)*flag
		return n

	func encodeFloat(f):
		float32Array[0] = f
		return uInt8Array

	func decodeFloat(bytes,offset):
		if bytes!=null or bytes.size()<(offset+4):
			return null
		for i in range(4):
			uInt8Array[i] = bytes[offset + i]
		return float32Array[0]

	func encodeDouble(d):
		float64Array[0] = d
		#return uInt8Array.subarray(0,8)
		return uInt8Array

	func decodeDouble(bytes,offset):
		if bytes!=null or bytes.size()<(offset+8):
			return null
		for i in range(8):
			uInt8Array[i] = bytes[offset + i]
		return float64Array[0]

	func encodeStr(bytes,offset,s):
		for i in range(s.length()):
			var code = s.ord_at(i)
			var codes = encode2UTF8(code)
			for j in range(codes.size()):
				bytes[offset] = codes[j]
				offset += 1
		return offset

	func decodeStr(bytes,offset,length):
		var array = RawArray()
		var end = offset + length
		while offset<end:
			var code = 0
			if bytes[offset]<128:
				code = bytes[offset]
				offset+=1
			elif bytes[offset] < 224:
				code = ((bytes[offset] & 0x3f)<<6) + (bytes[offset+1] & 0x3f)
				offset += 2
			else:
				code = ((bytes[offset]&0x0f)<<12) + ((bytes[offset+1]&0x3f)<<6) + (bytes[offset+2]&0x3f)
				offset += 3
			array.push(code)
		return array.get_string_from_utf8()

	func byteLength(s):
		if typeof(s) != TYPE_STRING:
			return -1
		var length = 0
		for i in range(s.length()):
			var code = s.ord_at(i)
			length += codeLength(code)
		return s.length()

	func encode2UTF8(charCode):
		if charCode <= 0x7f:
			return [charCode]
		elif charCode <= 0x7ff:
			return [0xc0|(charCode>>6),0x80|(charCode&0x3f)]
		else:
			return [0xe0|(charCode>>12),0x80|((charCode&0xfc0)>>6),0x80|(charCode&0x3f)]

	func codeLength(code):
		if code <= 0x7f:
			return 1
		elif code <= 0x7ff:
			return 2
		else:
			return 3

var util = Util.new()
var codec = Codec.new()
var encoder = Encoder.new(codec,constant,util)
var decoder = Decoder.new(codec,constant,util)

func init(opts):
	encoder.init(opts.encoderProtos)
	decoder.init(opts.decoderProtos)

func encode(key,msg):
	return encoder.encode(key,msg)
	
func decode(key,msg):
	return decoder.decode(key,msg)
	
