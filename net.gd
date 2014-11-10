extends Node

var socket = StreamPeerTCP.new()
var _accum = 0  # delta accumulator
var _active = false   # socket intended for use
var _connected = false  # socket is connected

const ERR = 1
var data

func _ready():
	data = get_node("/root/data")
	add_user_signal(data.RECV_SIGNAL)
	set_process(true)
	
func write(string):
	if(_connected):
		socket.put_partial_data(_string_to_raw_array(string))

func _string_to_raw_array(string):
	var msg = string + data.HEAD_STR
	var raw = RawArray()
	var len = msg.length()
	var i=0
	while(i<len):
		raw.push_back(msg.ord_at(i))
		i=i+1
	
	return raw

func conn(host, port):
	_active = true
	var err = socket.connect(host, port)
	_connected = socket.is_connected()
	return err

func disconnect():
	_active = false
	_connected = false
	socket.disconnect()

func _process(delta):
	if(not _active):
		pass
#	_accum += delta
#	write(1101,""+str(_accum))
	        
#	if(_accum > 1):
#		_accum = 0
	var connected = socket.is_connected()
	if(not connected):
		_respond("Lost Connection", ERR)
	else:
		var output = socket.get_partial_data(1024)
		var errCode = output[0]
		var outputData = output[1]
		
		if(errCode != 0):
			_respond( "ErrCode:" + str(errCode), ERR)
		else:
			var outStr = outputData.get_string_from_utf8()
			if(outStr != ""):
				_respond( outStr)

func _respond(msg, errCode = 0):
	if(errCode == 0):
		_respondOK(msg)
	elif(errCode == ERR):
		_respondErr(msg)

func _respondOK(msg):
	var msgStr
	data.temp_data += msg
	print (data.temp_data.find(data.HEAD_STR))
	if data.temp_data.find(data.HEAD_STR) != -1:				#starting from 1,not from 0
		var strArr = data.temp_data.split(data.HEAD_STR)
		var arrSize = strArr.size()
		
		for i in range(arrSize-1):
			data.data_arr.push_back(strArr[i])
		
		data.temp_data = strArr[arrSize - 1]
		_receive_data_arr_handler()

func _receive_data_arr_handler():
	while data.data_arr.size() > 0:
		var msg = data.data_arr[0]
		data.data_arr.remove(0)
		emit_signal(data.RECV_SIGNAL, msg)

func _respondErr(msg):
	emit_signal(data.ERR_SIGNAL, [msg])


func _get_sock_head():
	var raw = RawArray()
	return raw

func _get_push_back_raw(string):
	var len = string.length()
	var raw = RawArray()
	var i = 0
	while(i<len):
		raw.push_back(string.ord_at(i))
		i = i + 1
	return raw

