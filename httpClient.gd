extends Node

var reqId = 0
var reqs = {}

func _ready():
	set_process(true)
	
func _process(d):
	for key in reqs.keys():
		var req = reqs[key]
		if req.state == 1:
			if req.http.get_status()==HTTPClient.STATUS_CONNECTING or req.http.get_status()==HTTPClient.STATUS_RESOLVING:
				req.http.poll()
			else:
				if req.http.get_status() != HTTPClient.STATUS_CONNECTED:
					req.state = 4
					req.err = 'err when connecting.'
				else:
					req.err = req.http.request(HTTPClient.METHOD_POST,req.path,req.headers)
					if req.err == OK:
						req.state = 2
					else:
						req.state = 4
		elif req.state == 2:
			if req.http.get_status() == HTTPClient.STATUS_REQUESTING:
				req.http.poll()
			else:
				if req.http.get_status() != HTTPClient.STATUS_BODY and req.http.get_status() != HTTPClient.STATUS_CONNECTED:
					req.state = 4
					req.err = 'err when request.'
				else:
					if req.http.has_response():
						req.state = 3
					else:
						req.state = 4
		elif req.state == 3:
			if req.http.get_status()==HTTPClient.STATUS_BODY:
				req.http.poll()
				var chunk = req.http.read_response_body_chunk()
				if chunk.size()==0:
					pass
				else:
					req.rb = req.rb + chunk
			else:
				req.state = 4
		else:
			if req.err != OK:
				print('http err:',req.err)
			else:
				if req.isRaw:
					req.cb.call_func(req.rb)
				else:
					req.cb.call_func(req.rb.get_string_from_ascii())
			reqs.erase(key)
			print('cur http reqs size:',reqs.size())

func post(host,port,path,msg,cb,isRaw = false):
	var http = HTTPClient.new()
	var err = http.connect(host,port)
	msg = msg.to_json()
	var f = FuncRef.new()
	f.set_instance(cb.instance)
	f.set_function(cb.f)
	var headers=[
	"User-Agent: Pirulo/1.0 (Godot)",
	"Accept: */*",
	"Content-Type:application/x-www-form-urlencoded"
	]
	reqId += 1
	
	var state = 1
	if err != OK:
		state = 4
	
	reqs[reqId] = {
		http=http,
		state = state,
		msg = msg,
		cb = f,
		path = path,
		err = err,
		headers = headers,
		isRaw = isRaw,
		rb = RawArray()
	}

