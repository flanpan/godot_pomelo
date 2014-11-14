const TYPE_UINT32 = 0
const TYPE_SINT32 = 0
const TYPE_INT32 = 0
const TYPE_DOUBLE = 1
const TYPE_STRING = 2
const TYPE_MESSAGE = 2
const TYPE_FLOAT = 5

class Util:
	static func isSimpleType(type):
		return (type == "uInt32" || type == "sInt32" || type == "int32" || type=="uInt64" || type=="sInt64" || type=="float" || type=="double")

class Encoder:
	func encode(key,msg):
		pass

class Decoder:
	func decode(key,msg):
		pass

class Codec:
	var buffer = RawArray()
	var float32Array
	var float64Array
	var uInt8Array

	func _init():
		buffer.resize(8)
		float32Array = RealArray()
		float64Array = RealArray()
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
		#var array = []
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
		#var s = "";
		#for i in range(array.size()):
		#	str += 
		return array.get_string_from_utf8()

	func byteLength(s):
		if typeof(s) != TYPE_STRING:
			return -1
		#var length = 0
		#for i in range(s.length())
		#	var code = s.ord_at(i)
		return s.length()

	func encode2UTF8(charCode):
		if charCode <= 0x7f:
			return [charCode]
		elif charCode <= 0x7ff:
			return [0xc0|(charCode>>6),0x80|(charCode&0x3f)]
		else:
			return [0xe0|(charCode>>12),0x80|((charCode&0xfc0)>>6),0x80|(charCode&0x3f)]


var encoder = Encoder.new()
var decoder = Decoder.new()

func init(opts):
	encoder.init(opts.encoderProtos)
	decoder.init(opts.decoderProtos)

func encode(key,msg):
	return encoder.encode(key,msg)
	
func decode(key,msg):
	return decoder.decode(key,msg)
	
