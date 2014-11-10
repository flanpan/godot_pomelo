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

var encoder = Encoder.new()
var decoder = Decoder.new()

func init(opts):
	encoder.init(opts.encoderProtos)
	decoder.init(opts.decoderProtos)

func encode(key,msg):
	return encoder.encode(key,msg)
	
func decode(key,msg):
	return decoder.decode(key,msg)
	
